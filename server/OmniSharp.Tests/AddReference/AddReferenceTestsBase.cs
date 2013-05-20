using System;
using System.Xml.Linq;
using NUnit.Framework;
using OmniSharp.Solution;

namespace OmniSharp.Tests.AddReference
{
    public abstract class AddReferenceTestsBase
    {
        protected ISolution Solution;
        [SetUp]
        public void SetUp()
        {
            Solution = new FakeSolution(@"c:\test\fake.sln");
        }

        protected IProject CreateDefaultProject()
        {
            var project = new FakeProject("fakeone", @"c:\test\one\fake1.csproj", Guid.NewGuid())
                {
                    Title = "Project One",
                    XmlRepresentation = XDocument.Parse(@"
                <Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003"">
                    <ItemGroup>
                        <Compile Include=""Test.cs""/>
                    </ItemGroup>
                </Project>")
                };
            project.AddFile("some content", @"c:\test\one\test.cs");
            return project;
        }

        protected IProject CreateDefaultProjectWithFileReference()
        {
            var project = new FakeProject("fakeone", @"c:\test\one\fake1.csproj", Guid.NewGuid())
            {
                Title = "Project One",
                XmlRepresentation = XDocument.Parse(@"
                <Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003"">
                    <ItemGroup>
                        <Compile Include=""Test.cs""/>
                    </ItemGroup>
                    <ItemGroup>
                        <Reference Include=""Hello.World"">
                            <HintPath>..\packages\HelloWorld\lib\net40\Hello.World.dll</HintPath>
                        </Reference>
                    </ItemGroup>
                </Project>")
            };
            project.AddFile("some content", @"c:\test\one\test.cs");
            return project;
        }
    }
}