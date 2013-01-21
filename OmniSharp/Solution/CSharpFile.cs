using System;
using System.IO;
using System.Linq;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.Editor;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.Solution
{
    public class CSharpFile
    {
        public readonly IProject Project;
        public readonly string FileName;

        public readonly ITextSource Content;
        public readonly int LinesOfCode;
        public SyntaxTree SyntaxTree;
        public IUnresolvedFile ParsedFile;

        public CSharpFile(IProject project, string fileName) : this(project, fileName, File.ReadAllText(fileName))
        {
        }

        public CSharpFile(IProject project, string fileName, string source)
        {
            Console.WriteLine("Loading " + fileName);
            this.Project = project;
            this.FileName = fileName;
            this.Content = new StringTextSource(source);
            this.LinesOfCode = 1 + this.Content.Text.Count(c => c == '\n');

            CSharpParser p = project.CreateParser();
            this.SyntaxTree = p.Parse(Content.CreateReader(), fileName);
            if (p.HasErrors)
            {
                Console.WriteLine("Error parsing " + fileName + ":");
                foreach (var error in p.Errors)
                {
                    Console.WriteLine("  " + error.Region + " " + error.Message);
                }
            }
            this.ParsedFile = this.SyntaxTree.ToTypeSystem();
        }
    }
}