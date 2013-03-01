using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
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

        public FindUsagesHandler(BufferParser parser, ISolution solution)
        {
            _parser = parser;
            _solution = solution;
        }

        public FindUsagesResponse FindUsages(FindUsagesRequest request)
        {
            
            var res = _parser.ParsedContent(request.Buffer, request.FileName);
            var loc = new TextLocation(request.Line, request.Column);
            var result = new ConcurrentBag<AstNode>();
            var findReferences = new FindReferences();
            ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            if (resolveResult is LocalResolveResult)
            {
                var variable = (resolveResult as LocalResolveResult).Variable;
                findReferences.FindLocalReferences(variable, res.UnresolvedFile, res.SyntaxTree, res.Compilation, (node, rr) => result.Add(node), CancellationToken.None);
            }
            else
            {
                IEntity entity = null;
                if (resolveResult is TypeResolveResult)
                {
                    entity = (resolveResult as TypeResolveResult).Type.GetDefinition();
                }

                if (resolveResult is MemberResolveResult)
                {
                    entity = (resolveResult as MemberResolveResult).Member;
                }

                if (entity == null)
                {
                    return new FindUsagesResponse {Usages = new List<Usage>()};
                }
                var searchScopes = findReferences.GetSearchScopes(entity);

                var interesting = new List<CSharpUnresolvedFile>();

                foreach (var scope in searchScopes)
                {
                    var scopeInteresting = findReferences.GetInterestingFiles(scope, res.Compilation);
                    interesting.AddRange(scopeInteresting);
                }

                Parallel.ForEach(interesting, file =>
                    {
                        ParsedResult parsedResult = _parser.ParsedContent(
                            _solution.GetFile(file.FileName).Content.Text, file.FileName);
                        findReferences.FindReferencesInFile(searchScopes, file, parsedResult.SyntaxTree,
                                                            parsedResult.Compilation,
                                                            (node, rr) => result.Add(node), CancellationToken.None);
                    });

            }

            var usages = result.Select(node => new Usage
            {
                FileName = node.GetRegion().FileName,
                Text = node.Preview(_solution.GetFile(node.GetRegion().FileName)).Replace("'", "''"),
                Line = node.StartLocation.Line,
                Column = node.StartLocation.Column,
            });

            return new FindUsagesResponse { Usages = usages };
        }
    }

    public static class AstNodeExtensions
    {
        public static string Preview(this AstNode node, CSharpFile file)
        {
            var region = node.GetRegion();
            var location = node.StartLocation;
            var offset = file.Document.GetOffset(location.Line, location.Column);
            var line = file.Document.GetLineByNumber(location.Line);
            if (line.Length < 50)
            {
                return file.Document.GetText(line.Offset, line.Length);
            }

            var start = Math.Max(line.Offset, offset - 30);
            var end = Math.Min(line.EndOffset, offset + 30);

            return "..." + file.Document.GetText(start, end - start).Trim() + "...";
        }
    }

    public class Usage
    {
        public string FileName { get; set; }
        public int Line { get; set; }
        public int Column { get; set; }
        public string Text { get; set; }
    }
}