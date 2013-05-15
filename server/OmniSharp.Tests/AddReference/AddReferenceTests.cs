using System.Xml.Linq;
using NUnit.Framework;
using OmniSharp.AddReference;
using Should;

namespace OmniSharp.Tests.AddReference
{
    [TestFixture]
    public class AddReferenceTests
    {
         [Test]
         public void CanAddProjectReference()
         {
             var projectOne = new FakeProject("fakeone", @"c:\test\code\fake1.csproj");
             projectOne.AddFile("some content", @"c:\test\one\test.cs");
             projectOne.XmlRepresentation = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Test.cs""/></ItemGroup></Project>");

             var projectTwo = new FakeProject("faketwo", @"c:\test\code\fake2.csproj");
             projectTwo.AddFile("some content", @"c:\test\two\test.cs");
             projectTwo.XmlRepresentation = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Hello.cs""/><Compile Include=""Test.cs""/></ItemGroup></Project>");

             var expectedXml = XDocument.Parse(@"<Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003""><ItemGroup><Compile Include=""Test.cs""/></ItemGroup><ItemGroup><ProjectReference Include=""..\""><Project>{SOMEGUID}</Project><Name>fakeone</Name></ProjectReference></ItemGroup></Project>");

             var solution = new FakeSolution(@"c:\test\fake.sln");
             solution.Projects.Add(projectOne);
             solution.Projects.Add(projectTwo);

             var request = new AddReferenceRequest
             {
                 Reference = @"fakeone"
             };

             var handler = new AddReferenceHandler(solution);
             handler.AddReference(request);

             projectTwo.AsXml().ToString().ShouldEqual(expectedXml.ToString());
         }
    }
}