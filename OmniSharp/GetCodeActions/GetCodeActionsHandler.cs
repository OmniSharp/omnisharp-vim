using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp.Refactoring;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.Editor;
using OmniSharp.Parser;
using OmniSharp.Requests;

namespace OmniSharp.GetCodeActions
{
    public class GetCodeActionsHandler
    {
        private readonly BufferParser _bufferParser;

        public GetCodeActionsHandler(BufferParser bufferParser)
        {
            _bufferParser = bufferParser;
        }

        public GetCodeActionsResponse GetCodeActions(Request req)
        {
            var q = _bufferParser.ParsedContent(req.Buffer, req.FileName);
            var resolver = new CSharpAstResolver (q.Compilation, q.SyntaxTree, q.UnresolvedFile);
            var doc = new StringBuilderDocument(req.Buffer);
            var location = new TextLocation(req.Line, req.Column);
            var refactoringContext = new OmniSharpRefactoringContext(doc, location, resolver);
            //refactoringContext.FormattingOptions = formattingOptions;
            var types = Assembly.GetAssembly(typeof (ICodeActionProvider))
                                .GetTypes();

            var providerTypes = types.Where(t => typeof(ICodeActionProvider).IsAssignableFrom(t));

            IEnumerable<ICodeActionProvider> providers =
                providerTypes
                    .Where(type => !type.IsInterface)
                    .Where(type => !type.ContainsGenericParameters)
                    .Select(type => (ICodeActionProvider)Activator.CreateInstance(type));

            var actions = new List<CodeAction>();
            foreach (var provider in providers)
            {
                actions.AddRange(provider.GetActions(refactoringContext));
            }
            //return actions.Select(a => a.Description);
            return new GetCodeActionsResponse { CodeActions = actions.Select(a => a.Description) };
        }
    }
}