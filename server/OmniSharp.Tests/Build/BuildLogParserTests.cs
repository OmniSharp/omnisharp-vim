using NUnit.Framework;
using OmniSharp.Build;
using Should;

namespace OmniSharp.Tests.Build
{
    class BuildLogParserTests
    {
        [Test]
        public void Should_parse_syntax_error()
        {
            var logParser = new BuildLogParser();
            var quickfix = logParser.Parse(
                @"         c:\_src\OmniSharp\server\OmniSharp\Program.cs(12,34): error CS1002: ; expected [C:\_src\OmniSharp\server\OmniSharp\OmniSharp.csproj]");
            quickfix.FileName.ShouldEqual(@"c:\_src\OmniSharp\server\OmniSharp\Program.cs");
            quickfix.Line.ShouldEqual(12);
            quickfix.Column.ShouldEqual(34);
            quickfix.Text.ShouldEqual(
                @"; expected");
            
        }
        [Test]
        public void Should_parse_missing_file_error()
        {
            var logParser = new BuildLogParser();
            var quickfix = logParser.Parse(
                @"     CSC : error CS2001: Source file 'Bootstrapper.cs' could not be found [C:\_src\OmniSharp\server\OmniSharp\OmniSharp.csproj]");
            quickfix.Text.ShouldEqual(
                @"Source file ''Bootstrapper.cs'' could not be found [C:\_src\OmniSharp\server\OmniSharp\OmniSharp.csproj]");
            quickfix.FileName.ShouldEqual("Bootstrapper.cs");
        }
    }
}
