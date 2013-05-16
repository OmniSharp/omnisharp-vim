using System;
using System.Xml.Linq;
using NUnit.Framework;
using OmniSharp.Solution;

namespace OmniSharp.Tests.AddReference
{
    public abstract class AddReferenceBase
    {
        protected ISolution Solution;
        [SetUp]
        public void SetUp()
        {
            Solution = new FakeSolution(@"c:\test\fake.sln");
        }

        protected IProject CreateDefaultProject()
        {
            var projectOne = new FakeProject("fakeone", @"c:\test\one\fake1.csproj", Guid.NewGuid())
                {
                    Title = "Project One",
                    XmlRepresentation = XDocument.Parse(@"
                <Project xmlns=""http://schemas.microsoft.com/developer/msbuild/2003"">
                    <ItemGroup>
                        <Compile Include=""Test.cs""/>
                    </ItemGroup>
                </Project>")
                };
            projectOne.AddFile("some content", @"c:\test\one\test.cs");
            return projectOne;
        }
    }
}