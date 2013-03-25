using System;
using ICSharpCode.NRefactory;
using NUnit.Framework;
using Nancy.Testing;
using OmniSharp.TypeLookup;
using OmniSharp.Solution;
using Should;

namespace OmniSharp.Tests.TypeLookup
{
    [TestFixture]
    public class IntegrationTest
    {
        [Test]
        public void Should_lookup_Test()
        {
            string editorText = @"
public class Test
{
    public void Main()
    {
        Test test;
        te$st = new Test();
    }
}
";
            int cursorOffset = editorText.IndexOf("$", StringComparison.Ordinal);
            TextLocation cursorPosition = TestHelpers.GetLineAndColumnFromIndex(editorText, cursorOffset);
            editorText = editorText.Replace("$", "");

            var solution = new FakeSolution();
            var project = new FakeProject();
            project.AddFile(editorText);
            solution.Projects.Add(project);
            
            var bootstrapper = new ConfigurableBootstrapper(c => c.Dependency<ISolution>(solution));
            var browser = new Browser(bootstrapper);

            var result = browser.Post("/typelookup", with =>
            {
                with.HttpRequest();
                with.FormValue("FileName", "myfile");
                with.FormValue("Buffer", editorText);
                with.FormValue("Line", cursorPosition.Line.ToString());
                with.FormValue("Column", cursorPosition.Column.ToString());
            });

            var res = result.Body.DeserializeJson<TypeLookupResponse>();
            res.Type.ShouldEqual("Test test");
        }
    }
}
