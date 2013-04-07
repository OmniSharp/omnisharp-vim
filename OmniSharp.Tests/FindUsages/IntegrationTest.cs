using System.Linq;
using NUnit.Framework;
using Nancy.Testing;
using OmniSharp.FindUsages;
using OmniSharp.Solution;
using Should;

namespace OmniSharp.Tests.FindUsages
{
    [TestFixture]
    public class IntegrationTest
    {
        [Test]
        public void Should_find_usages_of_class()
        {
            const string editorText = 
@"public class myclass
{
    public void method() { }

    public void method_calling_method()
    {
        method();        
    }
}
";
            var solution = new FakeSolution();
            var project = new FakeProject();
            project.AddFile(editorText);
            solution.Projects.Add(project);

            var bootstrapper = new ConfigurableBootstrapper(c => c.Dependency<ISolution>(solution));
            var browser = new Browser(bootstrapper);

            var result = browser.Post("/findusages", with =>
            {
                with.HttpRequest();
                with.FormValue("FileName", "myfile");
                with.FormValue("Line", "3");
                with.FormValue("Column", "21");
                with.FormValue("Buffer", editorText);
            });

            var usages = result.Body.DeserializeJson<FindUsagesResponse>().Usages.ToArray();
            usages.Count().ShouldEqual(2);
            usages[0].Text.Trim().ShouldEqual("public void method() { }");
            usages[1].Text.Trim().ShouldEqual("method();");
        }
    }
}
