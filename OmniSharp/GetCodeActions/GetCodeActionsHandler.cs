using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Refactoring;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.Editor;
using ICSharpCode.NRefactory.TypeSystem;
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
            var actions = GetContextualCodeActions(req).ToList();
            if(req.CodeAction > actions.Count)
                return new RunCodeActionsResponse();

            CodeAction action = actions[req.CodeAction];
            var context = GetRefactoringContext(req);
            
            using (var script = new TestScript(context))
            {
                action.Run(script);
            }

            return new RunCodeActionsResponse {Text = context.Document.Text};
        }

        private IEnumerable<CodeAction> GetContextualCodeActions(Request req)
        {
            var refactoringContext = GetRefactoringContext(req);

            var actions = new List<CodeAction>();
            var providers = new CodeActionProviders().GetProviders();
            foreach (var provider in providers)
            {
                actions.AddRange(provider.GetActions(refactoringContext));
            }
            return actions;
        }

        private OmniSharpRefactoringContext GetRefactoringContext(Request req)
        {
            var q = _bufferParser.ParsedContent(req.Buffer, req.FileName);
            var resolver = new CSharpAstResolver(q.Compilation, q.SyntaxTree, q.UnresolvedFile);
            var doc = new StringBuilderDocument(req.Buffer);
            var location = new TextLocation(req.Line, req.Column);
            var refactoringContext = new OmniSharpRefactoringContext(doc, location, resolver);
            return refactoringContext;
        }
    }

    class TestScript : DocumentScript
    {
        readonly OmniSharpRefactoringContext context;
        public TestScript(OmniSharpRefactoringContext context)
            : base(context.Document, FormattingOptionsFactory.CreateAllman(), new TextEditorOptions())
        {
            this.context = context;
        }

        public override Task Link(params AstNode[] nodes)
        {
            // check that all links are valid.
            foreach (var node in nodes)
            {
                Debug.Assert(GetSegment(node) != null);
            }
            return new Task(() => { });
        }

        public override Task InsertWithCursor(string operation, InsertPosition defaultPosition, IEnumerable<AstNode> nodes)
        {
            var entity = context.GetNode<EntityDeclaration>();
            foreach (var node in nodes)
            {
                InsertBefore(entity, node);
            }
            var tcs = new TaskCompletionSource<object>();
            tcs.SetResult(null);
            return tcs.Task;
        }

        public override Task InsertWithCursor(string operation, ITypeDefinition parentType, IEnumerable<AstNode> nodes)
        {
            var unit = context.RootNode;
            var insertType = unit.GetNodeAt<TypeDeclaration>(parentType.Region.Begin);

            var startOffset = GetCurrentOffset(insertType.LBraceToken.EndLocation);
            foreach (var node in nodes.Reverse())
            {
                var output = OutputNode(1, node, true);
                if (parentType.Kind == TypeKind.Enum)
                {
                    InsertText(startOffset, output.Text + ",");
                }
                else
                {
                    InsertText(startOffset, output.Text);
                }
                output.RegisterTrackedSegments(this, startOffset);
            }
            var tcs = new TaskCompletionSource<object>();
            tcs.SetResult(null);
            return tcs.Task;
        }

        void Rename(AstNode node, string newName)
        {
            if (node is ObjectCreateExpression)
                node = ((ObjectCreateExpression)node).Type;

            if (node is InvocationExpression)
                node = ((InvocationExpression)node).Target;

            if (node is MemberReferenceExpression)
                node = ((MemberReferenceExpression)node).MemberNameToken;

            if (node is MemberType)
                node = ((MemberType)node).MemberNameToken;

            if (node is EntityDeclaration)
                node = ((EntityDeclaration)node).NameToken;

            if (node is ParameterDeclaration)
                node = ((ParameterDeclaration)node).NameToken;
            if (node is ConstructorDeclaration)
                node = ((ConstructorDeclaration)node).NameToken;
            if (node is DestructorDeclaration)
                node = ((DestructorDeclaration)node).NameToken;
            if (node is VariableInitializer)
                node = ((VariableInitializer)node).NameToken;
            Replace(node, new IdentifierExpression(newName));
        }

        public override void Rename(IEntity entity, string name)
        {
            FindReferences refFinder = new FindReferences();
            refFinder.FindReferencesInFile(refFinder.GetSearchScopes(entity),
                                           context.UnresolvedFile,
                                           context.RootNode as SyntaxTree,
                                           context.Compilation, (n, r) => Rename(n, name),
                                           context.CancellationToken);
        }

        public override void Rename(IVariable variable, string name)
        {
            FindReferences refFinder = new FindReferences();
            refFinder.FindLocalReferences(variable,
                                           context.UnresolvedFile,
                                           context.RootNode as SyntaxTree,
                                           context.Compilation, (n, r) => Rename(n, name),
                                           context.CancellationToken);
        }

        public override void RenameTypeParameter(IType type, string name = null)
        {
            FindReferences refFinder = new FindReferences();
            refFinder.FindTypeParameterReferences(type,
                                           context.UnresolvedFile,
                                           context.RootNode as SyntaxTree,
                                           context.Compilation, (n, r) => Rename(n, name),
                                           context.CancellationToken);
        }

        public override void CreateNewType(AstNode newType, NewTypeContext context)
        {
            var output = OutputNode(0, newType, true);
            InsertText(0, output.Text);
        }
    }
}