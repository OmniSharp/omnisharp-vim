using System;
using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.TypeSystem;
using OmniSharp.Solution;

namespace OmniSharp.Tests
{
    public class FakeProject : IProject
    {
        public string Name { get; set; }

        static readonly Lazy<IUnresolvedAssembly> mscorlib = new Lazy<IUnresolvedAssembly>(
            () => new CecilLoader().LoadAssemblyFile(typeof (object).Assembly.Location));
        
        static readonly Lazy<IUnresolvedAssembly> systemCore = new Lazy<IUnresolvedAssembly>(
            () => new CecilLoader().LoadAssemblyFile(typeof (Enumerable).Assembly.Location));
        
        public FakeProject(string name = "fake")
        {
            Name = name;
            Files = new List<CSharpFile>();
            this.ProjectContent = new CSharpProjectContent();
            this.ProjectContent.SetAssemblyName(name);
            this.ProjectContent.SetProjectFileName(name);
            this.ProjectContent = this.ProjectContent.AddAssemblyReferences(new [] { mscorlib.Value, systemCore.Value });
        }

        public void AddFile(string source, string fileName="myfile")
        {
            Files.Add(new CSharpFile(this, fileName, source));    
            this.ProjectContent = this.ProjectContent
                .AddOrUpdateFiles(Files.Select(f => f.ParsedFile));
        }

        public CSharpFile GetFile(string fileName)
        {
            return this.Files.SingleOrDefault(f => f.ParsedFile.FileName.Equals(fileName, StringComparison.InvariantCultureIgnoreCase));
        }

        public IProjectContent ProjectContent { get; set; }
        public string Title { get; set; }
        public string FileName { get; private set; }
        public List<CSharpFile> Files { get; private set; }
        public List<IAssemblyReference> References { get; set; }

        public CSharpParser CreateParser()
        {
            var settings = new CompilerSettings();
            return new CSharpParser(settings);
        }
    }
}
