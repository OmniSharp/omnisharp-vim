using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.Semantics;
using OmniSharp.Parser;

namespace OmniSharp.TypeLookup
{
    public class TypeLookupHandler
    {
        private readonly BufferParser _bufferParser;

        public TypeLookupHandler(BufferParser bufferParser)
        {
            _bufferParser = bufferParser;
        }

        public TypeLookupResponse GetTypeLookupResponse(TypeLookupRequest request)
        {
            var res = _bufferParser.ParsedContent(request.Buffer, request.FileName);
            var loc = new TextLocation(request.Line, request.Column);
            ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            var response = new TypeLookupResponse();
            if (resolveResult != null)
            {
                response.Type = resolveResult.ToString();
            }

            return response;
        }

    }
}
