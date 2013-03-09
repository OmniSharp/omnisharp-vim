﻿using System;
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

        public IEnumerable<ICompletionData> CreateProvider(AutoCompleteRequest request)
        {
            var editorText = request.Buffer ?? "";
            var filename = request.FileName;
            var partialWord = request.WordToComplete ?? "";

            var doc = new ReadOnlyDocument(editorText);
            var loc = new TextLocation(request.Line, request.Column - partialWord.Length);
            int cursorPosition = doc.GetOffset(loc);
            //Ensure cursorPosition only equals 0 when editorText is empty, so line 1,column 1
            //completion will work correctly.
            cursorPosition = Math.Max(cursorPosition, 1);
            cursorPosition = Math.Min(cursorPosition, editorText.Length);

            
            var res = _parser.ParsedContent(editorText, filename);
            var rctx = res.UnresolvedFile.GetTypeResolveContext(res.Compilation, loc);

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
