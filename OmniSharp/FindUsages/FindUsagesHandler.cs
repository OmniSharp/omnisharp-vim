using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using ICSharpCode.NRefactory;
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
        private FindReferences _findReferences;

        public FindUsagesHandler(BufferParser parser)
        {
            _parser = parser;
        }

        public FindUsagesResponse FindUsages(FindUsagesRequest req)
        {
            ParsedResult res = _parser.ParsedContent(req.Buffer, req.FileName);

            _findReferences = new FindReferences();
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
                    var searchScopes = _findReferences.GetSearchScopes(curMember);
                    var interesting = new List<CSharpUnresolvedFile>();
                    foreach (var scope in searchScopes)
                    {
                        var scopeInteresting = _findReferences.GetInterestingFiles(scope, res.Compilation);
                        interesting.AddRange(scopeInteresting);
                    }

                    foreach (var file in interesting)
                    {
                        ParsedResult parsedResult = _parser.ParsedContent(File.ReadAllText(file.FileName), file.FileName);
                        _findReferences.FindReferencesInFile(searchScopes, file, parsedResult.SyntaxTree, parsedResult.Compilation,
                                                     (node, rr) => result.Add(rr), CancellationToken.None);
                    }
                }


            }

            //IUnresolvedTypeDefinition curDef = resolveResult.Type;
            //if (curDef != null)
            //{
            //    ITypeDefinition resolvedDef = curDef.Resolve(rctx).GetDefinition();
            //    IMember curMember = resolvedDef.Members.FirstOrDefault(m => m.Region.Begin <= loc && loc < m.BodyRegion.End);
            //    if (curMember != null)
            //    {
            //        var searchScopes = _findReferences.GetSearchScopes(curMember);
            //        _findReferences.FindReferencesInFile(searchScopes, res.UnresolvedFile, res.SyntaxTree, res.Compilation,
            //                                             (node, rr) => result.Add(node), CancellationToken.None);
            //    }
            //}

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