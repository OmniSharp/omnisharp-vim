using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory.CSharp.Refactoring;
using OmniSharp.Common;
using OmniSharp.Parser;
using OmniSharp.Refactoring;

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
            var actions = GetContextualCodeActions(req).ToList();
            if(req.CodeAction > actions.Count)
                return new RunCodeActionsResponse();

            CodeAction action = actions[req.CodeAction];
            var context = OmniSharpRefactoringContext.GetContext(_bufferParser, req);
            
            using (var script = new OmniSharpScript(context))
            {
                action.Run(script);
            }

            return new RunCodeActionsResponse {Text = context.Document.Text};
        }

        private IEnumerable<CodeAction> GetContextualCodeActions(Request req)
        {
            var refactoringContext = OmniSharpRefactoringContext.GetContext(_bufferParser, req);

            var actions = new List<CodeAction>();
            var providers = new CodeActionProviders().GetProviders();
            foreach (var provider in providers)
            {
                var providerActions = provider.GetActions(refactoringContext);
                actions.AddRange(providerActions);
            }
            return actions;
        }
    }
}