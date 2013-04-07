using System;
using System.Linq;
using System.Text.RegularExpressions;
using ICSharpCode.NRefactory;
using NUnit.Framework;
using Nancy.Testing;
using OmniSharp.AutoComplete;
using OmniSharp.Solution;
using Should;

namespace OmniSharp.Tests.AutoComplete
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
            int cursorOffset = editorText.IndexOf("$", StringComparison.Ordinal);
            TextLocation cursorPosition = TestHelpers.GetLineAndColumnFromIndex(editorText, cursorOffset);
            string partialWord = GetPartialWord(editorText);
            editorText = editorText.Replace("$", "");

            var solution = new FakeSolution();
            var project = new FakeProject();
            project.AddFile(editorText);
            solution.Projects.Add(project);
            
            var bootstrapper = new ConfigurableBootstrapper(c => c.Dependency<ISolution>(solution));
            var browser = new Browser(bootstrapper);

            var result = browser.Post("/autocomplete", with =>
            {
                with.HttpRequest();
                with.FormValue("FileName", "myfile");
                with.FormValue("WordToComplete", partialWord);
                with.FormValue("Buffer", editorText);
                with.FormValue("Line", cursorPosition.Line.ToString());
                with.FormValue("Column", cursorPosition.Column.ToString());
            });

            var res = result.Body.DeserializeJson<AutoCompleteResponse[]>().Select(c => c.DisplayText);
            res.ShouldContain("Trim()");
        }

        private static string GetPartialWord(string editorText)
        {
            MatchCollection matches = Regex.Matches(editorText, @"([a-zA-Z0-9_]*)\$");
            return matches[0].Groups[1].ToString();
        }

        
    }
}
