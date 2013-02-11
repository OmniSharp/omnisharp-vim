using System;
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
using OmniSharp.Solution;

namespace OmniSharp.FindUsages
{
    public class FindUsagesHandler
    {
        private readonly BufferParser _parser;
        private readonly ISolution _solution;
        private readonly Logger _logger;
        private FindReferences _findReferences;

        public FindUsagesHandler(BufferParser parser, ISolution solution, Logger logger)
        {
            _parser = parser;
            _solution = solution;
            _logger = logger;
        }

        public FindUsagesResponse FindUsages(FindUsagesRequest req)
        {
            ParsedResult res = _parser.ParsedContent(req.Buffer, req.FileName);

            _findReferences = new FindReferences();
            var result = new List<AstNode>();

            var loc = new TextLocation(req.Line, req.Column);
            var rctx = new CSharpTypeResolveContext(res.Compilation.MainAssembly);
            var usingScope = res.UnresolvedFile.GetUsingScope(loc).Resolve(res.Compilation);
            rctx = rctx.WithUsingScope(usingScope);
            //ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            //var resolveResultLocation = resolveResult.GetDefinitionRegion();
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
                        _logger.Debug(scope.SearchTerm);

                        var scopeInteresting = _findReferences.GetInterestingFiles(scope, res.Compilation);
                        interesting.AddRange(scopeInteresting);
                    }
                    foreach (var file in interesting)
                    {
                        ParsedResult parsedResult = _parser.ParsedContent(File.ReadAllText(file.FileName), file.FileName);
                        _findReferences.FindReferencesInFile(searchScopes, file, parsedResult.SyntaxTree, parsedResult.Compilation,
                                                     (node, rr) => result.Add(node), CancellationToken.None);
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

            var usages = result.Select(node => node.GetRegion()).Select(region => new Usage
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