using System.Xml.Linq;
using FluentAssertions;
using NUnit.Framework;
using OmniSharp.AddToProject;
using OmniSharp.Solution;

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

             project.AsXml().Should().Be(expectedXml);
         }

        [Test]
        public void ShouldAddNewFileToProject()
        {
            var project = new FakeProject(fileName: @"c:\test\code\fake.csproj");
            project.XmlRepresentation = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/></ItemGroup></Project>");
            var expectedXml = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/><Compile Include=""Test.cs""/></ItemGroup></Project>");

            project.AddFile("some content", @"c:\test\code\Test.cs");
            
            var solution = new FakeSolution(@"c:\test\fake.sln");
            solution.Projects.Add(project);

            var request = new AddToProjectRequest
            {
                FileName = @"c:\test\code\Test.cs"
            };

            var handler = new AddToProjectHandler(solution);
            handler.AddToProject(request);

            project.AsXml().ToString().Should().Be(expectedXml.ToString());
        }

        [Test]
        public void ShouldNotAddNonCSharpFile()
        {
            var project = new FakeProject(fileName: @"c:\test\code\fake.csproj");

            var expectedXml = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/></ItemGroup></Project>");
            project.XmlRepresentation = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/></ItemGroup></Project>");

            project.AddFile("some content", @"c:\test\code\foo.txt");

            var solution = new FakeSolution(@"c:\test\fake.sln");
            solution.Projects.Add(project);

            var request = new AddToProjectRequest
            {
                FileName = @"c:\test\code\foo.txt"
            };

            var handler = new AddToProjectHandler(solution);
            handler.AddToProject(request);

            project.AsXml().ToString().Should().Be(expectedXml.ToString());
        }

        [Test]
        public void ShouldAlwaysUseWindowsFileSeparatorWhenAddingToProject()
        {
            var project = new FakeProject(fileName: @"/test/code/fake.csproj");
            project.XmlRepresentation = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/></ItemGroup></Project>");
            var expectedXml = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/><Compile Include=""folder\Test.cs""/></ItemGroup></Project>");

            project.AddFile("some content", @"/test/code/folder/Test.cs");

            var solution = new FakeSolution(@"/test/fake.sln");
            solution.Projects.Add(project);

            var request = new AddToProjectRequest
            {
                FileName = @"/test/code/folder/Test.cs"
            };

            var handler = new AddToProjectHandler(solution);
            handler.AddToProject(request);

            project.AsXml().ToString().Should().Be(expectedXml.ToString());
        }

        [Test, ExpectedException(typeof(ProjectNotFoundException))]
        public void ShouldThrowProjectNotFoundExceptionWhenProjectNotFound()
        {
            var project = new FakeProject(fileName: @"/test/code/fake.csproj");
            var solution = new FakeSolution(@"/test/fake.sln");
            solution.Projects.Add(project);

            var request = new AddToProjectRequest
            {
                FileName = @"/test/folder/Test.cs"
            };

            var handler = new AddToProjectHandler(solution);
            handler.AddToProject(request);
        }

        [Test, ExpectedException(typeof (ProjectNotFoundException))]
        public void ShouldThrowProjectNotFoundExceptionForOrphanProject()
        {
            var solution = new FakeSolution(@"/test/fake.sln");
            var project = new OrphanProject(solution);
            project.Files.Add(new CSharpFile(project, "/test/folder/Test.cs", "Some content..."));
            solution.Projects.Add(project);

            var request = new AddToProjectRequest
            {
                FileName = @"/test/folder/Test.cs"
            };

            var handler = new AddToProjectHandler(solution);
            handler.AddToProject(request);
        }
    }
}