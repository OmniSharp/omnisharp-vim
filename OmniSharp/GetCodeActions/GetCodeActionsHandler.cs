using System.Collections.Generic;
using System.Linq;
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
            var actions = GetContextualCodeActions(req);

            return new GetCodeActionsResponse { CodeActions = actions.Select(a => a.Description) };
        }

        public RunCodeActionsResponse RunCodeAction(RunCodeActionRequest req)
        {
            var actions = GetContextualCodeActions(req);
            var action = actions.First(a => a.Description == req.CodeAction);

        }

        private IEnumerable<CodeAction> GetContextualCodeActions(Request req)
        {
            var q = _bufferParser.ParsedContent(req.Buffer, req.FileName);
            var resolver = new CSharpAstResolver(q.Compilation, q.SyntaxTree, q.UnresolvedFile);
            var doc = new StringBuilderDocument(req.Buffer);
            var location = new TextLocation(req.Line, req.Column);
            var refactoringContext = new OmniSharpRefactoringContext(doc, location, resolver);

            var actions = new List<CodeAction>();

            foreach (var provider in CodeActionProviders.Providers)
            {
                actions.AddRange(provider.GetActions(refactoringContext));
            }
            return actions;
        }
    }
}