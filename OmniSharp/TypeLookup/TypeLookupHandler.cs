using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.Semantics;
using ICSharpCode.NRefactory.TypeSystem;
using ICSharpCode.NRefactory.TypeSystem.Implementation;
using OmniSharp.Parser;

namespace OmniSharp.TypeLookup
{
    public class TypeLookupHandler
    {
        private readonly BufferParser _bufferParser;

        private static readonly ConversionFlags AmbienceFlags =
            ConversionFlags.ShowBody |
            ConversionFlags.ShowModifiers |
            ConversionFlags.ShowReturnType |
            ConversionFlags.ShowParameterList |
            ConversionFlags.ShowParameterNames |
            ConversionFlags.ShowDeclaringType;

        public TypeLookupHandler(BufferParser bufferParser)
        {
            _bufferParser = bufferParser;
        }

        public TypeLookupResponse GetTypeLookupResponse(TypeLookupRequest request)
        {
            var res = _bufferParser.ParsedContent(request.Buffer, request.FileName);
            var loc = new TextLocation(request.Line, request.Column);
            var resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            var response = new TypeLookupResponse();
            var ambience = new CSharpAmbience()
                {
                    ConversionFlags = AmbienceFlags,
                };


            if (resolveResult == null || resolveResult is NamespaceResolveResult)
                response.Type = "";
            else if (resolveResult != null)
            {
                response.Type = resolveResult.Type.ToString();

                if (resolveResult is CSharpInvocationResolveResult)
                {
                    var result = resolveResult as CSharpInvocationResolveResult;
                    response.Type = ambience.ConvertEntity(result.Member);
                }
                else if (resolveResult is LocalResolveResult)
                {
                    var result = resolveResult as LocalResolveResult;
                    response.Type = ambience.ConvertVariable(result.Variable);
                }
                else if (resolveResult is MemberResolveResult)
                {
                    var result = resolveResult as MemberResolveResult;
                    response.Type = ambience.ConvertEntity(result.Member);
                }
                else if (resolveResult is TypeResolveResult)
                {
                    ambience.ConversionFlags |= ConversionFlags.UseFullyQualifiedTypeNames;
                    response.Type = ambience.ConvertType(resolveResult.Type);
                }

                if (resolveResult.Type is UnknownType)
                    response.Type = "Unknown Type: " + resolveResult.Type.Name;
                if (resolveResult.Type == SpecialType.UnknownType)
                    response.Type = "Unknown Type";
            }

            return response;
        }

    }
}
