using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Refactoring;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.Refactoring
{
    public class OmniSharpScript : DocumentScript
    {
        readonly OmniSharpRefactoringContext _context;
        public OmniSharpScript(OmniSharpRefactoringContext context)
            : base(context.Document, FormattingOptionsFactory.CreateAllman(), new TextEditorOptions())
        {
            _context = context;
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
            var entity = _context.GetNode<EntityDeclaration>();
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
            var unit = _context.RootNode;
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

        public void Rename(AstNode node, string newName)
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
                                           _context.UnresolvedFile,
                                           _context.RootNode as SyntaxTree,
                                           _context.Compilation, (n, r) => Rename(n, name),
                                           _context.CancellationToken);
        }

        public override void Rename(IVariable variable, string name)
        {
            FindReferences refFinder = new FindReferences();
            refFinder.FindLocalReferences(variable,
                                          _context.UnresolvedFile,
                                          _context.RootNode as SyntaxTree,
                                          _context.Compilation, (n, r) => Rename(n, name),
                                          _context.CancellationToken);
        }

        public override void RenameTypeParameter(IType type, string name = null)
        {
            FindReferences refFinder = new FindReferences();
            refFinder.FindTypeParameterReferences(type,
                                                  _context.UnresolvedFile,
                                                  _context.RootNode as SyntaxTree,
                                                  _context.Compilation, (n, r) => Rename(n, name),
                                                  _context.CancellationToken);
        }

        public override void CreateNewType(AstNode newType, NewTypeContext context)
        {
            var output = OutputNode(0, newType, true);
            InsertText(0, output.Text);
        }
    }
}