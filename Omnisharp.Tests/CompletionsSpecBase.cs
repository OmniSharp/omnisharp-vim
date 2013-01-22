using System.Collections.Generic;
using System.Text.RegularExpressions;
using ICSharpCode.NRefactory.Completion;
using OmniSharp;

namespace Omnisharp.Tests
{
    public class CompletionsSpecBase
    {
        readonly FakeSolution _solution;

        public CompletionsSpecBase()
        {
            _solution = new FakeSolution();
        }

        public IEnumerable<ICompletionData> GetCompletions(string editorText)
        {
            var project = new FakeProject();
            project.AddFile(editorText.Replace("$", ""));
            _solution.Projects.Add("dummyproject", project);
            var provider = new CompletionProvider(_solution, new Logger());
            var partialWord = GetPartialWord(editorText);
            var cursorPosition = editorText.IndexOf("$", System.StringComparison.Ordinal);
            // vim removes the word to complete.... so we do here also
            editorText = editorText.Remove(cursorPosition - partialWord.Length, partialWord.Length);
            return provider.CreateProvider("myfile", partialWord, editorText.Replace("$", ""), cursorPosition, true);
        }

        private static string GetPartialWord(string editorText)
        {
            var matches = Regex.Matches(editorText, @"([a-zA-Z_]*)\$");
            return matches[0].Groups[1].ToString();
        }
    }
}