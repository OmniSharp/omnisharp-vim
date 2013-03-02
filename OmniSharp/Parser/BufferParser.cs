using System;
using System.Linq;
using ICSharpCode.NRefactory.CSharp;
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
            IProjectContent pctx;
            var syntaxTree = new CSharpParser().Parse(editorText, filename);
            syntaxTree.Freeze();
            CSharpUnresolvedFile parsedFile = syntaxTree.ToTypeSystem();

            var project = ProjectContainingFile(filename);
            if (project == null)
            {
                // First we know about this file
                //TODO: if the file isn't part of the solution, we need to add the file to an appropriate project
                project = _solution.Projects.First().Value;
                parsedFile = (CSharpUnresolvedFile) new CSharpFile(project, filename, editorText).ParsedFile;
                pctx = project.ProjectContent;
                pctx = pctx.AddOrUpdateFiles(parsedFile);
            }
            else
            {
                pctx = project.ProjectContent;
                IUnresolvedFile oldFile = pctx.GetFile(filename);
                pctx = pctx.AddOrUpdateFiles(oldFile, parsedFile);
            }

            var editedFile = _solution.GetFile(filename);
            //If GetFile couldn't find a file, it will return null
            //this will happen when an project-less file is loaded
            if (editedFile != null)
                editedFile.Update(editorText);

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

        private IProject ProjectContainingFile(string filename)
        {
            return _solution.Projects.Values.FirstOrDefault(p => p.Files.Any(f => f.FileName.Equals(filename, StringComparison.InvariantCultureIgnoreCase)));
        }
    }
}
