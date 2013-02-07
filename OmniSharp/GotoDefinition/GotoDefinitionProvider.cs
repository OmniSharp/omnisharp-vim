using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.Semantics;
using OmniSharp.Parser;

namespace OmniSharp.GotoDefinition
{
    public class GotoDefinitionProvider
    {
        private readonly EditorTextParser _editorTextParser;

        public GotoDefinitionProvider(EditorTextParser editorTextParser)
        {
            _editorTextParser = editorTextParser;
        }

        public GotoDefinitionResponse GetGotoDefinitionResponse(GotoDefinitionRequest request)
        {
            var res = _editorTextParser.ParsedContent(request.Buffer, request.FileName);
            
            var loc = new TextLocation(request.Line, request.Column);

            ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            var response = new GotoDefinitionResponse();
            if (resolveResult != null)
            {
                var region = resolveResult.GetDefinitionRegion();

                response.FileName = region.FileName;
                response.Line = region.BeginLine;
                response.Column = region.BeginColumn;
            }

            return response;
        }

    }
}