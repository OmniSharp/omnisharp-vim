using System;
using ICSharpCode.NRefactory.CSharp;
using OmniSharp.Solution;

namespace OmniSharp.FindUsages
{
    public static class AstNodeExtensions
    {
        public static string Preview(this AstNode node, CSharpFile file, int maxWidth)
        {
            var startLocation = node.StartLocation;
            var startOffset = file.Document.GetOffset(startLocation.Line, startLocation.Column);
            

            var line = file.Document.GetLineByNumber(startLocation.Line);

            var lineText = file.Document.GetText(line.Offset, line.Length);
            
            if (line.Length < maxWidth)
            {
                // Don't truncate
                return lineText;
            }

            var endLocation = node.EndLocation;
            var endOffset = file.Document.GetOffset(endLocation.Line, endLocation.Column);

            const string ellipsis = "...";

            var charactersEitherSide = (maxWidth - (ellipsis.Length * 2));

            // Place the node text as close as possible to the centre of the returned text
            var start = Math.Max(line.Offset, startOffset - charactersEitherSide); 
            var end = Math.Min(line.EndOffset, endOffset + charactersEitherSide); 

            return ellipsis + file.Document.GetText(start, end - start).Trim() + ellipsis;
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
