using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using ICSharpCode.NRefactory.Completion;
using OmniSharp;
using OmniSharp.AutoComplete;
using OmniSharp.Parser;
using OmniSharp.Requests;

namespace Omnisharp.Tests.CompletionTests
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
            int cursorPosition = editorText.IndexOf("$", StringComparison.Ordinal);
            string partialWord = GetPartialWord(editorText);
            editorText = editorText.Replace("$", "");

            var project = new FakeProject();
            project.AddFile(editorText);
            _solution.Projects.Add("dummyproject", project);
            var provider = new CompletionProvider(new EditorTextParser(_solution), new Logger());
            var request = new AutocompleteRequest
                {
                    FileName = "myfile",
                    WordToComplete = partialWord,
                    Buffer = editorText,
                    CursorPosition = cursorPosition
                };

            return provider.CreateProvider(request);
        }

        private static string GetPartialWord(string editorText)
        {
            MatchCollection matches = Regex.Matches(editorText, @"([a-zA-Z_]*)\$");
            return matches[0].Groups[1].ToString();
        }
    }
}