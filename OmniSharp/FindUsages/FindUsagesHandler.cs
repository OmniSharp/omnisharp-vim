using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.Semantics;
using ICSharpCode.NRefactory.TypeSystem;
using OmniSharp.Parser;

namespace OmniSharp.FindUsages
{
    public class FindUsagesHandler
    {
        private readonly BufferParser _parser;
        

        public FindUsagesHandler(BufferParser parser)
        {
            _parser = parser;
        }

        public FindUsagesResponse FindUsages(FindUsagesRequest request)
        {
            var res = _parser.ParsedContent(request.Buffer, request.FileName);
            
            var loc = new TextLocation(request.Line, request.Column);

            ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            resolveResult.Type.GetDefinition();
            var findReferences = new FindReferences();
            var searchScopes = findReferences.GetSearchScopes(resolveResult.Type.GetDefinition());

            var interesting = new List<CSharpUnresolvedFile>();

            foreach (var scope in searchScopes)
            {
                var scopeInteresting = findReferences.GetInterestingFiles(scope, res.Compilation);
                interesting.AddRange(scopeInteresting);
            }

            var result = new List<AstNode>();

            foreach (var file in interesting)
            {
                ParsedResult parsedResult = _parser.ParsedContent(File.ReadAllText(file.FileName), file.FileName);
                findReferences.FindReferencesInFile(searchScopes, file, parsedResult.SyntaxTree, parsedResult.Compilation,
                                             (node, rr) => result.Add(node), CancellationToken.None);
            }

            var usages = result.Select(node =>  new Usage
            {
                FileName = node.GetRegion().FileName,
                Line = node.StartLocation.Line,
                Column = node.StartLocation.Column
            });

            return new FindUsagesResponse { Usages = usages };

        }
        public FindUsagesResponse FindUsages2(FindUsagesRequest req)
        {
            ParsedResult res = _parser.ParsedContent(req.Buffer, req.FileName);
            var findReferences = new FindReferences();
            var result = new List<ResolveResult>();

            var loc = new TextLocation(req.Line, req.Column);
            var rctx = new CSharpTypeResolveContext(res.Compilation.MainAssembly);
            var usingScope = res.UnresolvedFile.GetUsingScope(loc).Resolve(res.Compilation);
            rctx = rctx.WithUsingScope(usingScope);
            
            IUnresolvedTypeDefinition curDef = res.UnresolvedFile.GetInnermostTypeDefinition(loc);
            if (curDef != null)
            {
                ITypeDefinition resolvedDef = curDef.Resolve(rctx).GetDefinition();
                IMember curMember = resolvedDef.Members.FirstOrDefault(m => m.Region.Begin <= loc && loc < m.BodyRegion.End);
                if (curMember != null)
                
                {

                    //var typeEntity = res.Compilation.FindType().GetDefinition();
                    //var searchScopes = findReferences.GetSearchScopes(typeEntity);
                    var searchScopes = findReferences.GetSearchScopes(curMember);
                    var interesting = new List<CSharpUnresolvedFile>();
                    foreach (var scope in searchScopes)
                    {
                        var scopeInteresting = findReferences.GetInterestingFiles(scope, res.Compilation);
                        interesting.AddRange(scopeInteresting);
                    }

                    foreach (var file in interesting)
                    {
                        ParsedResult parsedResult = _parser.ParsedContent(File.ReadAllText(file.FileName), file.FileName);
                        findReferences.FindReferencesInFile(searchScopes, file, parsedResult.SyntaxTree, parsedResult.Compilation,
                                                     (node, rr) => result.Add(rr), CancellationToken.None);
                    }
                }
            }

            var usages = result.Select(node => node.GetDefinitionRegion()).Select(region => new Usage
                {
                    FileName = region.FileName,
                    Line = region.BeginLine,
                    Column = region.BeginColumn
                });

            return new FindUsagesResponse { Usages = usages };
        }
    }

    public class Usage
    {
        public string FileName { get; set; }
        public int Line { get; set; }
        public int Column { get; set; }
    }
}