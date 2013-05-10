using System.Xml.Linq;
using NUnit.Framework;
using OmniSharp.AddToProject;

namespace OmniSharp.Tests.AddToProject
{
    [TestFixture]
    public class AddToProjectTests
    {
         [Test]
         public void ShouldNotAddFileToProjectWhenAlreadyExists()
         {
             var project = new FakeProject(fileName: @"c:\test\code\fake.csproj");
             project.AddFile("some content", @"c:\test\code\test.cs");

             project.XmlRepresentation = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/><Compile Include=""Test.cs""/></ItemGroup></Project>");
             var expectedXml = project.XmlRepresentation;

             var solution = new FakeSolution(@"c:\test\fake.sln");
             solution.Projects.Add(project);

             var request = new AddToProjectRequest
                 {
                     FileName = @"c:\test\code\test.cs"
                 };

             var handler = new AddToProjectHandler(solution);
             handler.AddToProject(request);

             Assert.That(project.AsXml(), Is.EqualTo(expectedXml));
         }

        [Test]
        public void ShouldAddNewFileToProject()
        {
            var project = new FakeProject(fileName: @"c:\test\code\fake.csproj");
            project.AddFile("some content", @"c:\test\code\Test.cs");

            project.XmlRepresentation = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/></ItemGroup></Project>");

            var expectedXml = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/><Compile Include=""Test.cs""/></ItemGroup></Project>");

            var solution = new FakeSolution(@"c:\test\fake.sln");
            solution.Projects.Add(project);

            var request = new AddToProjectRequest
            {
                FileName = @"c:\test\code\Test.cs"
            };

            var handler = new AddToProjectHandler(solution);
            handler.AddToProject(request);

            Assert.That(project.AsXml(), Is.EqualTo(expectedXml));
        }
    }
}