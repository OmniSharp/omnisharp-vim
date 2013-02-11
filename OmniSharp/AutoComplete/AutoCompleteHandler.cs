using System;
using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp.Completion;
using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.Completion;
using ICSharpCode.NRefactory.Editor;
using ICSharpCode.NRefactory.TypeSystem;
using OmniSharp.Parser;

namespace OmniSharp.AutoComplete
{
    public class AutoCompleteHandler
    {
        private readonly BufferParser _parser;
        private readonly Logger _logger;

        public AutoCompleteHandler(BufferParser parser, Logger logger)
        {
            _parser = parser;
            _logger = logger;
        }

        public IEnumerable<ICompletionData> CreateProvider(AutocompleteRequest request)
        {
            var cursorPosition = request.CursorPosition;
            var editorText = request.Buffer;
            var filename = request.FileName;
            var partialWord = request.WordToComplete ?? "";
            cursorPosition = Math.Min(cursorPosition, editorText.Length);
            cursorPosition = Math.Max(cursorPosition, 0);

            
            var doc = new ReadOnlyDocument(editorText);

            TextLocation loc = doc.GetLocation(cursorPosition - partialWord.Length);
            var res = _parser.ParsedContent(editorText, filename);

            var rctx = new CSharpTypeResolveContext(res.Compilation.MainAssembly);
            var usingScope = res.UnresolvedFile.GetUsingScope(loc).Resolve(res.Compilation);
            rctx = rctx.WithUsingScope(usingScope);
            _logger.Debug(usingScope);

            IUnresolvedTypeDefinition curDef = res.UnresolvedFile.GetInnermostTypeDefinition(loc);
            if (curDef != null)
            {
                ITypeDefinition resolvedDef = curDef.Resolve(rctx).GetDefinition();
                rctx = rctx.WithCurrentTypeDefinition(resolvedDef);
                IMember curMember = resolvedDef.Members.FirstOrDefault(m => m.Region.Begin <= loc && loc < m.BodyRegion.End);
                if (curMember != null)
                    rctx = rctx.WithCurrentMember(curMember);
            }
            ICompletionContextProvider contextProvider = new DefaultCompletionContextProvider(doc, res.UnresolvedFile);
            var engine = new CSharpCompletionEngine(doc, contextProvider, new CompletionDataFactory(partialWord), res.ProjectContent, rctx)
                {
                    EolMarker = Environment.NewLine
                };

            _logger.Debug("Getting Completion Data");

            IEnumerable<ICompletionData> data = engine.GetCompletionData(cursorPosition, true);
            _logger.Debug("Got Completion Data");

            return data.Where(d => d != null && d.DisplayText.IsValidCompletionFor(partialWord))
                       .FlattenOverloads()
                       .RemoveDupes()
                       .OrderBy(d => d.DisplayText);
        }
    }
}
