using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.TypeSystem;
using OmniSharp.Solution;

namespace OmniSharp.Parser
{
    public class BufferParser
    {
        private readonly ISolution _solution;

        public BufferParser(ISolution solution)
        {
            _solution = solution;
        }

        public ParsedResult ParsedContent(string editorText, string filename)
        {
            var project = _solution.ProjectContainingFile(filename);
            project.GetFile(filename).Update(editorText);

            var syntaxTree = project.CreateParser().Parse(editorText, filename);

            CSharpUnresolvedFile parsedFile = syntaxTree.ToTypeSystem();

            var pctx = project.ProjectContent.AddOrUpdateFiles(parsedFile);
            project.ProjectContent = pctx;

            ICompilation cmp = pctx.CreateCompilation();
            
            return new ParsedResult
                {
                    ProjectContent = pctx,
                    Compilation = cmp,
                    UnresolvedFile = parsedFile,
                    SyntaxTree = syntaxTree
                };
        }
    }
}
