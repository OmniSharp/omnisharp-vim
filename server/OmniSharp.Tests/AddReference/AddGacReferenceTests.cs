using System.Xml.Linq;
using NUnit.Framework;
using OmniSharp.AddReference;
using Should;

namespace OmniSharp.Tests.AddReference
{
    [TestFixture]
    public class AddGacReferenceTests : AddReferenceTestsBase
    {
         [Test,Ignore]
         public void CanAddGacAssemblyReference()
         {
             var project = CreateDefaultProject();
             Solution.Projects.Add(project);

             var expectedXml = XDocument.Parse(@"
                <Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003"">
                    <ItemGroup>
                        <Compile Include=""Test.cs""/>
                    </ItemGroup>
                    <ItemGroup>
                        <Reference Include=""System.Web.Mvc"" />
                    </ItemGroup>
                </Project>");

             var request = new AddReferenceRequest
             {
                 Reference = @"System.Web.Mvc",
                 FileName = @"c:\test\one\test.cs"
             };

             var handler = new AddReferenceHandler(Solution, new AddReferenceProcessorFactory(Solution, new IReferenceProcessor[]{new AddProjectReferenceProcessor(Solution) }));
             handler.AddReference(request);

             project.AsXml().ToString().ShouldEqual(expectedXml.ToString());

         }

        [Test, Ignore]
        public void WillNotAddDuplicateGacAssemblyReference()
        {
            
        }
    }
}