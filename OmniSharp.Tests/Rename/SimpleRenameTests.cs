using System.Linq;
using NUnit.Framework;
using OmniSharp.FindUsages;
using OmniSharp.Parser;
using OmniSharp.Rename;
using Should;

namespace OmniSharp.Tests.Rename
{
    [TestFixture]
    public class SimpleRenameTests
    {
        private string Rename(string buffer, string renameTo)
        {
            var location = TestHelpers.GetLineAndColumnFromDollar(buffer);
            buffer = buffer.Replace("$", "");
            var solution = new FakeSolution();
            var project = new FakeProject();
            project.AddFile(buffer);
            solution.Projects.Add("dummyproject", project);
            var bufferParser = new BufferParser(solution);
            var renameHandler = new RenameHandler(bufferParser, new FindUsagesHandler(bufferParser, solution));
            var request = new RenameRequest
                {
                    Buffer = buffer,
                    Column = location.Column - 1,
                    Line = location.Line,
                    RenameTo = renameTo,
                    FileName = "myfile"
                };

            var response = renameHandler.Rename(request);
            return response.Changes.First().Buffer;
        }

        [Test]
        public void Should_rename_variable()
        {
            Rename(
@"public class MyClass
{
    public MyClass()
    {
        var s$ = String.Empty;
    }
}", "str").ShouldEqual(
@"public class MyClass
{
    public MyClass()
    {
        var str = String.Empty;
    }
}"
 );
        }

        [Test]
        public void Should_rename_variable_and_usage()
        {
            Rename(
@"public class MyClass
{
    public MyClass()
    {
        var s$ = ""s"";
        s = s + s;
    }
}", "str")
  .ShouldEqual(
@"public class MyClass
{
    public MyClass()
    {
        var str = ""s"";
        str = str + str;
    }
}"
 );
        }

        [Test]
        public void Should_rename_field_and_usage()
        {
            Rename(
@"public class MyClass
{
    private string _s;
    public MyClass()
    {
        _s$ = ""s"";
    }
}", "_str")
  .ShouldEqual(
@"public class MyClass
{
    private string _str;
    public MyClass()
    {
        _str = ""s"";
    }
}"
 );
        }

        [Test]
        public void Should_rename_method()
        {
            Rename(
@"public class MyClass
{
    public MyClass()
    {
        MyMethod$();
    }

    void MyMethod()
    {
        
    }
}", "RenamedMethod")
.ShouldEqual(
@"public class MyClass
{
    public MyClass()
    {
        RenamedMethod();
    }

    void RenamedMethod()
    {
        
    }
}"
);            
        }
    }
}
