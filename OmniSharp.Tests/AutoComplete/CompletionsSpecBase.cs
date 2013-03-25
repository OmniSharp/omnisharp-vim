using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.Completion;
using OmniSharp.AutoComplete;
using OmniSharp.Parser;

namespace OmniSharp.Tests.AutoComplete
{
    public class CompletionsSpecBase
    {
        private readonly FakeSolution _solution;

        public CompletionsSpecBase()
        {
            _solution = new FakeSolution();
        }

        public IEnumerable<ICompletionData> GetCompletions(string editorText)
        {
            int cursorOffset = editorText.IndexOf("$", StringComparison.Ordinal);
            if(cursorOffset == -1)
                throw new ArgumentException("Editor text should contain a $");

            TextLocation cursorPosition = TestHelpers.GetLineAndColumnFromIndex(editorText, cursorOffset);
            string partialWord = GetPartialWord(editorText);
            editorText = editorText.Replace("$", "");

            var project = new FakeProject();
            project.AddFile(editorText);
            _solution.Projects.Add(project);
            var provider = new AutoCompleteHandler(new BufferParser(_solution), new Logger());
            var request = new AutoCompleteRequest
                {
                    FileName = "myfile",
                    WordToComplete = partialWord,
                    Buffer = editorText,
                    Line = cursorPosition.Line,
                    Column = cursorPosition.Column,
                };

            return provider.CreateProvider(request);
        }

        private static string GetPartialWord(string editorText)
        {
            MatchCollection matches = Regex.Matches(editorText, @"([a-zA-Z0-9_]*)\$");
            return matches[0].Groups[1].ToString();
        }
    }
}
