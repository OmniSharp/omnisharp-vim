using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using ICSharpCode.NRefactory.Completion;
using OmniSharp;
using OmniSharp.AutoComplete;
using OmniSharp.Parser;

namespace Omnisharp.Tests.CompletionTests.AutoComplete
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
            Tuple<int, int> cursorPosition = GetLineAndColumnFromIndex(editorText, cursorOffset);
            string partialWord = GetPartialWord(editorText);
            editorText = editorText.Replace("$", "");

            var project = new FakeProject();
            project.AddFile(editorText);
            _solution.Projects.Add("dummyproject", project);
            var provider = new AutoCompleteHandler(new BufferParser(_solution), new Logger());
            var request = new AutocompleteRequest
                {
                    FileName = "myfile",
                    WordToComplete = partialWord,
                    Buffer = editorText,
                    CursorLine = cursorPosition.Item1,
                    CursorColumn = cursorPosition.Item2,
                };

            return provider.CreateProvider(request);
        }

        private static string GetPartialWord(string editorText)
        {
            MatchCollection matches = Regex.Matches(editorText, @"([a-zA-Z_]*)\$");
            return matches[0].Groups[1].ToString();
        }

        private static Tuple<int, int> GetLineAndColumnFromIndex(string text, int index)
        {
            int lineCount = 1, lastLineEnd = -1;
            for (int i = 0; i < index; i++)
                if (text[i] == '\n')
                {
                    lineCount++;
                    lastLineEnd = i;
                }

            return new Tuple<int, int>(lineCount, index - lastLineEnd);
        }
    }
}