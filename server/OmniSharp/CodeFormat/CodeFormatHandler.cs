using System;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.Editor;
using OmniSharp.Common;

namespace OmniSharp.CodeFormat
{
    public class CodeFormatHandler  
    {
        public CodeFormatResponse Format(Request request)
        {
            var document = new StringBuilderDocument(request.Buffer);
            var options = new TextEditorOptions();
            options.EolMarker = Environment.NewLine;
            options.WrapLineLength = 80;
            var policy = FormattingOptionsFactory.CreateAllman();
            var visitor = new AstFormattingVisitor(policy, document, options);
            visitor.FormattingMode = FormattingMode.Intrusive;
            var syntaxTree = new CSharpParser().Parse(document, request.FileName);
            syntaxTree.AcceptVisitor(visitor);
            visitor.ApplyChanges();
            return new CodeFormatResponse(document.Text);
        }
    }
}