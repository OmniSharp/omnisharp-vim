using System;
using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.Semantics;
using ICSharpCode.NRefactory.TypeSystem;
using OmniSharp.Parser;
using OmniSharp.Solution;

namespace OmniSharp.GotoImplementation
{
    public class GotoImplementationHandler
    {
        private readonly ISolution _solution;
        private readonly BufferParser _bufferParser;

        public GotoImplementationHandler(ISolution solution, BufferParser bufferParser)
        {
            _solution = solution;
            _bufferParser = bufferParser;
        }

        public GotoImplementationResponse FindDerivedMembers(GotoImplementationRequest request)
        {
            var res = _bufferParser.ParsedContent(request.Buffer, request.FileName);

            var loc = new TextLocation(request.Line, request.Column);

            ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);

            var rctx = new CSharpTypeResolveContext(res.Compilation.MainAssembly);
            var usingScope = res.UnresolvedFile.GetUsingScope(loc).Resolve(res.Compilation);
            rctx = rctx.WithUsingScope(usingScope);

            if (resolveResult is TypeResolveResult)
            {
                return GetTypeResponse(rctx, (resolveResult as TypeResolveResult).Type.GetDefinition());
            }

            if (resolveResult is MemberResolveResult)
            {
                return GetMemberResponse(rctx, resolveResult as MemberResolveResult);
            }

            return new GotoImplementationResponse();
        }

        private GotoImplementationResponse GetTypeResponse(CSharpTypeResolveContext rctx, ITypeDefinition typeDefinition)
        {
            var types = GetAllTypes().Select(t => t.Resolve(rctx).GetDefinition());
            var locations = from type in types where type != null 
                                && type != typeDefinition 
                                && type.IsDerivedFrom(typeDefinition)
                            select type.Region
                            into region
                            select new Location
                                {
                                    FileName = region.FileName,
                                    Line = region.BeginLine,
                                    Column = region.BeginColumn
                                };

            return new GotoImplementationResponse {Locations = locations};
        }

        private GotoImplementationResponse GetMemberResponse(CSharpTypeResolveContext rctx, MemberResolveResult resolveResult)
        {
            var locations = new List<Location>();
            //TODO: we don't need to scan all types in all projects
            foreach (IUnresolvedTypeDefinition type in GetAllTypes())
            {
                ITypeDefinition resolvedDef = type.Resolve(rctx).GetDefinition();
                if (resolvedDef != null)
                {
                    IMember member =
                        InheritanceHelper.GetDerivedMember(resolveResult.Member, resolvedDef);
                    if (member != null)
                    {
                        var region = member.MemberDefinition.Region;
                        var location = new Location
                            {
                                FileName = region.FileName,
                                Line = region.BeginLine,
                                Column = region.BeginColumn
                            };
                        locations.Add(location);
                    }
                }
            }
            return new GotoImplementationResponse { Locations = locations };
        }

        private IEnumerable<IUnresolvedTypeDefinition> GetAllTypes()
        {
            return _solution.Projects.SelectMany(project => project.ProjectContent.GetAllTypeDefinitions());
        }
    }

    public static class TypeExtensions
    {
        #region GetAllBaseTypeDefinitions (borrowed from NRefactory master)
        /// <summary>
        /// Gets all base type definitions.
        /// The output is ordered so that base types occur before derived types.
        /// </summary>
        /// <remarks>
        /// This is equivalent to type.GetAllBaseTypes().Select(t => t.GetDefinition()).Where(d => d != null).Distinct().
        /// </remarks>
        public static IEnumerable<ITypeDefinition> GetAllBaseTypeDefinitions(this IType type)
        {
            if (type == null)
                throw new ArgumentNullException("type");

            return type.GetAllBaseTypes().Select(t => t.GetDefinition()).Where(d => d != null).Distinct();
        }

        /// <summary>
        /// Gets whether this type definition is derived from the base type definition.
        /// </summary>
        public static bool IsDerivedFrom(this ITypeDefinition type, ITypeDefinition baseType)
        {
            if (type.Compilation != baseType.Compilation)
            {
                throw new InvalidOperationException("Both arguments to IsDerivedFrom() must be from the same compilation.");
            }
            return type.GetAllBaseTypeDefinitions().Contains(baseType);
        }
        #endregion
    }
}
