using System.Threading;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp.Refactoring;
using ICSharpCode.NRefactory.CSharp.Resolver;
using ICSharpCode.NRefactory.Editor;

namespace OmniSharp.GetCodeActions
{
    public class OmniSharpRefactoringContext : RefactoringContext
    {
        private readonly IDocument _document;
        private readonly TextLocation _location;

        public OmniSharpRefactoringContext(IDocument document, TextLocation location, CSharpAstResolver resolver)
            : base(resolver, CancellationToken.None)
        {
            _document = document;
            _location = location;
        }

        public IDocument Document { get { return _document; } }

        public override int GetOffset(TextLocation location)
        {
            return _document.GetOffset(location);
        }

        public override IDocumentLine GetLineByOffset(int offset)
        {
            return _document.GetLineByOffset(offset);
        }

        public override TextLocation GetLocation(int offset)
        {
            return _location;
        }

        public override string GetText(int offset, int length)
        {
            return _document.GetText(offset, length);
        }

        public override string GetText(ISegment segment)
        {
            return _document.GetText(segment);
        }

        public override TextLocation Location
        {
            get { return _location; }
        }

        //public static OmniSharpRefactoringContext Create(string content)
        //{
        //    //int idx = content.IndexOf("$");
        //    //if (idx >= 0)
        //    //    content = content.Substring(0, idx) + content.Substring(idx + 1);
        //    //int idx1 = content.IndexOf("<-");
        //    //int idx2 = content.IndexOf("->");

        //    //int selectionStart = 0;
        //    //int selectionEnd = 0;
        //    //if (0 <= idx1 && idx1 < idx2)
        //    //{
        //    //    content = content.Substring(0, idx2) + content.Substring(idx2 + 2);
        //    //    content = content.Substring(0, idx1) + content.Substring(idx1 + 2);
        //    //    selectionStart = idx1;
        //    //    selectionEnd = idx2 - 2;
        //    //    idx = selectionEnd;
        //    //}

        //    var doc = new StringBuilderDocument(content);
        //    var parser = new CSharpParser();
        //    var unit = parser.Parse(content, "program.cs");
            

        //    unit.Freeze();
        //    var unresolvedFile = unit.ToTypeSystem();

        //    IProjectContent pc = new CSharpProjectContent();
        //    pc = pc.AddOrUpdateFiles(unresolvedFile);
        //    pc = pc.AddAssemblyReferences(new[] { CecilLoaderTests.Mscorlib, CecilLoaderTests.SystemCore });

        //    var compilation = pc.CreateCompilation();
        //    var resolver = new CSharpAstResolver(compilation, unit, unresolvedFile);
        //    TextLocation location = TextLocation.Empty;
        //    if (idx >= 0)
        //        location = doc.GetLocation(idx);
        //    return new OmniSharpRefactoringContext(doc, location, resolver)
        //    {
        //        selectionStart = selectionStart,
        //        selectionEnd = selectionEnd
        //    };
        //}
		
    }
}