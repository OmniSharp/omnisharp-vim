using System;
using System.Linq;
using System.Text.RegularExpressions;
using NUnit.Framework;
using Nancy.Testing;
using OmniSharp;
using OmniSharp.AutoComplete;
using OmniSharp.Requests;
using Should;

namespace Omnisharp.Tests.CompletionTests
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
            int cursorPosition = editorText.IndexOf("$", StringComparison.Ordinal);
            string partialWord = GetPartialWord(editorText);
            editorText = editorText.Replace("$", "");

            var project = new FakeProject();
            project.AddFile(editorText);
            solution.Projects.Add("dummyproject", project);
            var provider = new CompletionProvider(solution, new Logger());
            var request = new AutocompleteRequest
            {
                FileName = "myfile",
                WordToComplete = partialWord,
                Buffer = editorText,
                CursorPosition = cursorPosition
            };

            var bootstrapper = new ConfigurableBootstrapper(c => c.Dependency<CompletionProvider>(provider));
            var browser = new Browser(bootstrapper);

            var result = browser.Post("/autocomplete", with =>
            {
                with.HttpRequest();
                with.FormValue("FileName", "myfile");
                with.FormValue("WordToComplete", partialWord);
                with.FormValue("Buffer", editorText);
                with.FormValue("CursorPosition", cursorPosition.ToString());
            });

            var res = result.Body.DeserializeJson<CompletionDataDto[]>().Select(c => c.DisplayText);
            res.ShouldContain("Trim()");
        }

        private static string GetPartialWord(string editorText)
        {
            MatchCollection matches = Regex.Matches(editorText, @"([a-zA-Z_]*)\$");
            return matches[0].Groups[1].ToString();
        }
    }
}
