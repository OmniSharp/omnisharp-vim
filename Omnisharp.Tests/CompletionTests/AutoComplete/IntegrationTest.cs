using System;
using System.Linq;
using System.Text.RegularExpressions;
using NUnit.Framework;
using Nancy.Testing;
using OmniSharp.AutoComplete;
using OmniSharp.Solution;
using Should;

namespace Omnisharp.Tests.CompletionTests.AutoComplete
{
    [TestFixture]
    public class IntegrationTest
    {
        [Test]
        public void Should_complete_string()
        {
            string editorText = @"
public class myclass
{
    public void method()
    {
        string s;
        s.$;
    }
}
";
            var solution = new FakeSolution();
            int cursorOffset = editorText.IndexOf("$", StringComparison.Ordinal);
            Tuple<int, int> cursorPosition = GetLineAndColumnFromIndex(editorText, cursorOffset);
            string partialWord = GetPartialWord(editorText);
            editorText = editorText.Replace("$", "");

            var project = new FakeProject();
            project.AddFile(editorText);
            solution.Projects.Add("dummyproject", project);
            
            var bootstrapper = new ConfigurableBootstrapper(c => c.Dependency<ISolution>(solution));
            var browser = new Browser(bootstrapper);

            var result = browser.Post("/autocomplete", with =>
            {
                with.HttpRequest();
                with.FormValue("FileName", "anewfile.cs");
                with.FormValue("WordToComplete", partialWord);
                with.FormValue("Buffer", editorText);
                with.FormValue("CursorLine", cursorPosition.Item1.ToString());
                with.FormValue("CursorColumn", cursorPosition.Item2.ToString());
            });

            var res = result.Body.DeserializeJson<AutoCompleteResponse[]>().Select(c => c.DisplayText);
            res.ShouldContain("Trim()");
        }

        private static string GetPartialWord(string editorText)
        {
            MatchCollection matches = Regex.Matches(editorText, @"([a-zA-Z0-9_]*)\$");
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
