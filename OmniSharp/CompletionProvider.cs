using System;
using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Completion;
using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.Completion;
using ICSharpCode.NRefactory.Editor;
using ICSharpCode.NRefactory.TypeSystem;
using OmniSharp.Solution;

namespace OmniSharp
{
    public class CompletionProvider
    {
        private readonly ISolution _solution;
        private readonly Logger _logger;

        public CompletionProvider(ISolution solution, Logger logger)
        {
            _solution = solution;
            _logger = logger;
        }

        public IProject ProjectContainingFile(string filename)
        {
            return _solution.Projects.Values.FirstOrDefault(p => p.Files.Any(f => f.FileName.Equals(filename, StringComparison.InvariantCultureIgnoreCase)));
        }

        public IEnumerable<ICompletionData> CreateProvider(string filename, string partialWord, string text, int cursorPosition, bool isCtrlSpace)
        {
            //var editorText = ReconstructEditorText(partialWord, text, cursorPosition);
            string editorText;
            //if (cursorPosition > text.Length)
            //{
            //    editorText = ReconstructEditorText(partialWord, text, cursorPosition);
            //}
            //else
            {
                if (text != "")
                {
                    editorText = text;
                    cursorPosition -= partialWord.Length;
                }
                else
                {
                    editorText = partialWord;
                }    
            }

            //cursorPosition = Math.Min(cursorPosition, editorText.Length);
            string parsedText = text;
            var project = ProjectContainingFile(filename);
            if (project == null)
                return Enumerable.Empty<ICompletionData>();
            IProjectContent pctx = project.ProjectContent;
            if (pctx == null)
                return Enumerable.Empty<ICompletionData>();
            IUnresolvedFile oldFile = pctx.GetFile(filename);
            var compilationUnit = new CSharpParser().Parse(parsedText, filename);
            compilationUnit.Freeze();
            var parsedFile = compilationUnit.ToTypeSystem();
            pctx = pctx.AddOrUpdateFiles(oldFile, parsedFile);
            project.ProjectContent = pctx;
            ICompilation cmp = pctx.CreateCompilation();

            var doc = new ReadOnlyDocument(editorText);

            TextLocation loc = doc.GetLocation(cursorPosition);

            var rctx = new CSharpTypeResolveContext(cmp.MainAssembly);
            rctx = rctx.WithUsingScope(parsedFile.GetUsingScope(loc).Resolve(cmp));


            IUnresolvedTypeDefinition curDef = parsedFile.GetInnermostTypeDefinition(loc);
            if (curDef != null)
            {
                ITypeDefinition resolvedDef = curDef.Resolve(rctx).GetDefinition();
                rctx = rctx.WithCurrentTypeDefinition(resolvedDef);
                IMember curMember = resolvedDef.Members.FirstOrDefault(m => m.Region.Begin <= loc && loc < m.BodyRegion.End);
                if (curMember != null)
                    rctx = rctx.WithCurrentMember(curMember);
            }
            ICompletionContextProvider contextProvider = new DefaultCompletionContextProvider(doc, parsedFile);
            var engine = new CSharpCompletionEngine(doc, contextProvider, new CompletionDataFactory(partialWord), pctx, rctx);

            engine.EolMarker = Environment.NewLine;
            //engine.FormattingPolicy = new CSharpFormattingOptions();
            _logger.Debug("Getting Completion Data");

            IEnumerable<ICompletionData> data = engine.GetCompletionData(cursorPosition, isCtrlSpace);
            _logger.Debug("Got Completion Data");

            return data.Where(d => d != null && d.DisplayText.IsValidCompletionFor(partialWord))
                       .FlattenOverloads()
                       .OrderBy(d => d.DisplayText);
        }

        private static string ReconstructEditorText(string partialWord, string text, int cursorPosition)
        {
            // Vim sends us the text without the current word to be completed.
            // We have to put it back in here

            string editorText;

            if (text == "")
            {
                editorText = partialWord;
            }
            else
            {
                if (partialWord == "")
                {
                    editorText = text;
                }
                else
                {
                    editorText = text.Substring(0, cursorPosition - partialWord.Length) + partialWord;

                    if (cursorPosition < text.Length)
                    {
                        editorText +=
                            text.Substring(cursorPosition);
                    }
                }
            }
            return editorText;
        }
    }

    public static class CompletionDataExtenstions
    {
        public static IEnumerable<ICompletionData> FlattenOverloads(this IEnumerable<ICompletionData> completions)
        {
            var res = new List<ICompletionData>();
            foreach (var completion in completions)
            {
                res.AddRange(completion.HasOverloads ? completion.OverloadedData : new[] { completion });
            }
            return res;
        }

        public static IEnumerable<ICompletionData> RemoveDupes(this IEnumerable<ICompletionData> data)
        {
            return data.GroupBy(x => x.DisplayText,
                                (k, g) => g.Aggregate((a, x) => (CompareTo(x, a) == -1) ? x : a));
        }

        private static int CompareTo(ICompletionData a, ICompletionData b)
        {
            if (a.CompletionCategory == null && b.CompletionCategory == null)
                return 0;
            if (a.CompletionCategory == null)
                return -1;
            if (b.CompletionCategory == null)
                return 1;
            return a.CompletionCategory.CompareTo(b.CompletionCategory);
        }
    }

}
