using System.Collections.Generic;
using System.Linq;
using NUnit.Framework;
using OmniSharp.Parser;
using OmniSharp.Rename;
using Should;

namespace OmniSharp.Tests.Rename
{
    [TestFixture]
    public class MultiFileRenameTests
    {
        private IEnumerable<ModifiedFileResponse> Rename(string renameTo, params Buffer[] buffers)
        {
            RenameRequest request = null;
            var solutionBuilder = new FakeSolutionBuilder();
            foreach (var buffer in buffers)
            {
                if (buffer.Text.Contains("$"))
                {
                    var location = TestHelpers.GetLineAndColumnFromDollar(buffer.Text);
                    buffer.Text = buffer.Text.Replace("$", "");
                    request = new RenameRequest
                    {
                        Buffer = buffer.Text,
                        Column = location.Column - 1,
                        Line = location.Line,
                        RenameTo = renameTo,
                        FileName = buffer.Filename
                    };
                }
                //solutionBuilder = solutionBuilder.AddProject();
                solutionBuilder = solutionBuilder.AddFile(buffer.Text, buffer.Filename);
            }
            var solution = solutionBuilder.Build();
            var bufferParser = new BufferParser(solution);        
            var renameHandler = new RenameHandler(solution, bufferParser);

            var response = renameHandler.Rename(request);
            return response.Changes;
        }

        [Test]
        public void Should_rename_derived_type_usages()
        {
            var request = new Buffer(
@"public class Request
{
    public string Col$umn { get; set; }
}", "Request.cs");

            var findUsagesRequest = new Buffer("public class FindUsagesRequest : Request {}", "FindUsagesRequest.cs");
            var handler = new Buffer(
@"public class Handler
{
    public Handler()
    {
        var req = new FindUsagesRequest();
        req.Column = 1;
    }
}", "Handler.cs");

            var changedFiles = Rename("ColumnRenamed", request, findUsagesRequest, handler).ToList();
            changedFiles[1].Buffer.ShouldEqual(
@"public class Request
{
    public string ColumnRenamed { get; set; }
}");
            changedFiles[0].Buffer.ShouldEqual(

@"public class Handler
{
    public Handler()
    {
        var req = new FindUsagesRequest();
        req.ColumnRenamed = 1;
    }
}");
        }
    }
}

