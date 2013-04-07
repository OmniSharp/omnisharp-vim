﻿using System;
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
using OmniSharp.Requests;
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
                            .OrderBy(n => n.GetRegion().FileName.FixPath())
                            .ThenBy(n => n.StartLocation.Line)
                            .ThenBy(n => n.StartLocation.Column);
                            
            var res = new FindUsagesResponse();
            if (result.Any())
            {
                var usages = result.Select(node => new Usage
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
                    FindOnlySpecializedReferences = true
                };

            ResolveResult resolveResult = ResolveAtLocation.Resolve(res.Compilation, res.UnresolvedFile, res.SyntaxTree, loc);
            if (resolveResult is LocalResolveResult)
            {
                var variable = (resolveResult as LocalResolveResult).Variable;
                findReferences.FindLocalReferences(variable, res.UnresolvedFile, res.SyntaxTree, res.Compilation,
                                                   (node, rr) => _result.Add(node), CancellationToken.None);
            }
            else
            {
                IEntity entity = null;
                if (resolveResult is TypeResolveResult)
                {
                    var type = (resolveResult as TypeResolveResult).Type;
                    entity = type.GetDefinition();
                    ProcessTypeResults(type);
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
                    }
                    else
                    {
                        ProcessMemberResults(resolveResult);    
                    }
                }

                if (entity == null)
                    return _result;

                var searchScopes = findReferences.GetSearchScopes(entity);

                var interesting = new List<CSharpUnresolvedFile>();

                //foreach (var scope in searchScopes)
                //{
                //    var scopeInteresting = findReferences.GetInterestingFiles(scope, res.Compilation);
                //    interesting.AddRange(scopeInteresting);
                //}
                interesting = (from project in _solution.Projects
                              from file in project.Files
                              select (file.ParsedFile as CSharpUnresolvedFile)).ToList();

                Parallel.ForEach(interesting, file =>
                    {
                        //var content = _solution.GetFile(file.FileName).Content.Text;
                        //if (content.Contains(searchScopes.First().SearchTerm))
                        {
                            ParsedResult parsedResult = _parser.ParsedContent(
                                _solution.GetFile(file.FileName).Content.Text, file.FileName);

                            //TODO: According to this, http://community.sharpdevelop.net/forums/t/14337.aspx
                            // Compilation shouldn't be the source compilation..... but this code doesn't
                            // find public properties when I use the target compilation
                            findReferences.FindReferencesInFile(searchScopes, file, parsedResult.SyntaxTree,
                                                                parsedResult.Compilation,
                                                                (node, rr) => _result.Add(node), CancellationToken.None);
                        }
                    });
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
                while (declarationNode.GetNextNode() != null
                       && !(IsIdentifier(declarationNode)))
                {
                    declarationNode = declarationNode.GetNextNode();
                }

                if (IsIdentifier(declarationNode))
                    _result.Add(declarationNode);
            }
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
}