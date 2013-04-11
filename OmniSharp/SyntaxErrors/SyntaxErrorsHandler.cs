using System.Linq;
using OmniSharp.Common;
using OmniSharp.Parser;

namespace OmniSharp.SyntaxErrors
{
    public class SyntaxErrorsHandler
    {
        private readonly BufferParser _bufferParser;

        public SyntaxErrorsHandler(BufferParser bufferParser)
        {
            _bufferParser = bufferParser;
        }

        public SyntaxErrorsResponse FindSyntaxErrors(Request request)
        {
            var res = _bufferParser.ParsedContent(request.Buffer, request.FileName);

            var errors = res.SyntaxTree.Errors.Select(error => new Error
                {
                    Message = error.Message.Replace("'", "''"),
                    Column = error.Region.BeginColumn,
                    Line = error.Region.BeginLine,
                    FileName = request.FileName
                });

            return new SyntaxErrorsResponse {Errors = errors};
        }
    }
}