using ICSharpCode.NRefactory.CSharp;

namespace OmniSharp.Extensions
{
    static class NodeExtensions
    {
        public static AstNode GetIdentifier(this AstNode node)
        {
            if (node is ObjectCreateExpression)
                node = ((ObjectCreateExpression)node).Type;

            if (node is InvocationExpression)
                node = ((InvocationExpression)node).Target;

            if (node is MemberReferenceExpression)
                node = ((MemberReferenceExpression)node).MemberNameToken;

            if (node is SimpleType)
                node = ((SimpleType)node).IdentifierToken;

            if (node is MemberType)
                node = ((MemberType)node).MemberNameToken;

            if (node is TypeDeclaration)
                node = ((TypeDeclaration)node).NameToken;
            if (node is DelegateDeclaration)
                node = ((DelegateDeclaration)node).NameToken;

            if (node is EntityDeclaration)
                node = ((EntityDeclaration)node).NameToken;

            if (node is ParameterDeclaration)
                node = ((ParameterDeclaration)node).NameToken;
            if (node is ConstructorDeclaration)
                node = ((ConstructorDeclaration)node).NameToken;
            if (node is DestructorDeclaration)
                node = ((DestructorDeclaration)node).NameToken;
            if (node is NamedArgumentExpression)
                node = ((NamedArgumentExpression)node).NameToken;
            if (node is NamedExpression)
                node = ((NamedExpression)node).NameToken;
            if (node is VariableInitializer)
                node = ((VariableInitializer)node).NameToken;

            if (node is IdentifierExpression)
            {
                node = ((IdentifierExpression)node).IdentifierToken;
            }

            return node;
        }
    }
}
