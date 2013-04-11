using System;
using ICSharpCode.NRefactory.CSharp;
using OmniSharp.Solution;

namespace OmniSharp.FindUsages
{
    public static class AstNodeExtensions
    {
        public static string Preview(this AstNode node, CSharpFile file)
        {
            var location = node.StartLocation;
            var offset = file.Document.GetOffset(location.Line, location.Column);
            var line = file.Document.GetLineByNumber(location.Line);
            if (line.Length < 50)
            {
                return file.Document.GetText(line.Offset, line.Length);
            }

            var start = Math.Max(line.Offset, offset - 60);
            var end = Math.Min(line.EndOffset, offset + 60);

            return "..." + file.Document.GetText(start, end - start).Trim() + "...";
        }

		public static AstNode GetDefinition(this AstNode node)
		{
			if (node is ConstructorInitializer)
				return null;
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

			if (node is IdentifierExpression) {
				node = ((IdentifierExpression)node).IdentifierToken;
			}
			return node;
		}
    }
}
