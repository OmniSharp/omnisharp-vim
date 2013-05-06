using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.Semantics;
using ICSharpCode.NRefactory.TypeSystem;
using MonoDevelop.Ide.FindInFiles;
using OmniSharp.Common;
using OmniSharp.Extensions;
using OmniSharp.Parser;
using OmniSharp.Solution;

namespace OmniSharp.FindUsages
{
    public class FindUsagesHandler
    {
        private readonly BufferParser _parser;
        private readonly ISolution _solution;
        private ConcurrentBag<AstNode> _result;

        public FindUsagesHandler(BufferParser parser, ISolution solution)
        {
            _parser = parser;
            _solution = solution;
        }

        public FindUsagesResponse FindUsages(FindUsagesRequest request)
        {
            var result = FindUsageNodes(request)
                            .Distinct(new NodeComparer())
                            .OrderBy(n => n.GetRegion().FileName.FixPath())
                            .ThenBy(n => n.StartLocation.Line)
                            .ThenBy(n => n.StartLocation.Column);
                            
            var res = new FindUsagesResponse();
            if (result.Any())
            {
                var usages = result.Select(node => new QuickFix
                {
                    FileName = node.GetRegion().FileName,
                    Text = node.Preview(_solution.GetFile(node.GetRegion().FileName)).Replace("'", "''"),
                    Line = node.StartLocation.Line,
                    Column = node.StartLocation.Column,
                });
                res.Usages = usages;
            }

            return res;
        }

        public IEnumerable<AstNode> FindUsageNodes(Request request)
        {
            var res = _parser.ParsedContent(request.Buffer, request.FileName);
            var loc = new TextLocation(request.Line, request.Column);
            _result = new ConcurrentBag<AstNode>();
            var findReferences = new FindReferences
                {
                    FindCallsThroughInterface = true,
                    FindCallsThroughVirtualBaseMethod = true,
                    FindTypeReferencesEvenIfAliased = true,
                };

            ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            if (resolveResult is LocalResolveResult)
            {
                var variable = (resolveResult as LocalResolveResult).Variable;
                findReferences.FindLocalReferences(variable, res.UnresolvedFile, res.SyntaxTree, res.Compilation,
                                                   (node, rr) => _result.Add(node.GetDefinition()), CancellationToken.None);
            }
            else
            {
                IEntity entity = null;
                IEnumerable<IList<IFindReferenceSearchScope>> searchScopes = null;
                if (resolveResult is TypeResolveResult)
                {
                    var type = (resolveResult as TypeResolveResult).Type;
                    entity = type.GetDefinition();
                    ProcessTypeResults(type);
                    searchScopes = new[] {findReferences.GetSearchScopes(entity)};
                }

                if (resolveResult is MemberResolveResult)
                {
                    entity = (resolveResult as MemberResolveResult).Member;
                    if (entity.EntityType == EntityType.Constructor)
                    {
                        // process type instead
                        var type = entity.DeclaringType;
                        entity = entity.DeclaringTypeDefinition;
                        ProcessTypeResults(type);
                        searchScopes = new[] {findReferences.GetSearchScopes(entity)};
                    }
                    else
                    {
                        ProcessMemberResults(resolveResult);
                        var members = MemberCollector.CollectMembers(_solution,
                                                                     (resolveResult as MemberResolveResult).Member);
                        searchScopes = members.Select(findReferences.GetSearchScopes);
                    }
                }

                if (entity == null)
                    return _result;

                var interesting = new List<CSharpUnresolvedFile>();

                foreach (var project in _solution.Projects)
                {
                    var pctx = project.ProjectContent.CreateCompilation();
                    interesting = (from file in project.Files
                                   select (file.ParsedFile as CSharpUnresolvedFile)).ToList();

                    foreach (var file in interesting)
                    {
                        string text = _solution.GetFile(file.FileName).Content.Text;
                        var unit = new CSharpParser().Parse(text, file.FileName);
                        foreach (var scope in searchScopes)
                        {
                            findReferences.FindReferencesInFile(scope, file, unit,
                                                                pctx,
                                                                (node, rr) => _result.Add(node.GetIdentifier()),
                                                                CancellationToken.None);
                        }
                    }
                }
            }
            return _result;
        }

        private void ProcessMemberResults(ResolveResult resolveResult)
        {
            //TODO: why does FindReferencesInFile not return the definition for a field? 
            // add it here instead for now. 
            var definition = resolveResult.GetDefinitionRegion();
            ProcessRegion(definition);
        }

        private void ProcessRegion(DomRegion definition)
        {
            var file =_solution.GetFile(definition.FileName);
            if (file == null)
                return;
            var syntaxTree = file.SyntaxTree;
            var declarationNode = syntaxTree.GetNodeAt(definition.BeginLine, definition.BeginColumn);
            if (declarationNode != null)
            {
                declarationNode = FindIdentifier(declarationNode);

                if (IsIdentifier(declarationNode))
                    _result.Add(declarationNode);
            }
        }

        private static AstNode FindIdentifier(AstNode declarationNode)
        {
            while (declarationNode.GetNextNode() != null
                   && !(IsIdentifier(declarationNode)))
            {
                declarationNode = declarationNode.GetNextNode();
            }
            return declarationNode;
        }

        private void ProcessTypeResults(IType type)
        {
            //TODO: why does FindReferencesInFile not return the constructors?
            foreach (var constructor in type.GetConstructors())
            {
                var definition = constructor.MemberDefinition.Region;
                ProcessRegion(definition);
            }
        }

        private static bool IsIdentifier(AstNode declarationNode)
        {
            return declarationNode is VariableInitializer || declarationNode is Identifier;
        }
    }

    public class NodeComparer : IEqualityComparer<AstNode>
    {
        public bool Equals(AstNode x, AstNode y)
        {
            return x.StartLocation == y.StartLocation;
        }

        public int GetHashCode(AstNode obj)
        {
            return base.GetHashCode();
        }
    }
}
