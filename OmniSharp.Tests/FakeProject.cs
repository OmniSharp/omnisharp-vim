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
        static readonly Lazy<IUnresolvedAssembly> mscorlib = new Lazy<IUnresolvedAssembly>(
            () => new CecilLoader().LoadAssemblyFile(typeof (object).Assembly.Location));
        
        static readonly Lazy<IUnresolvedAssembly> systemCore = new Lazy<IUnresolvedAssembly>(
            () => new CecilLoader().LoadAssemblyFile(typeof (Enumerable).Assembly.Location));
        
        public FakeProject()
        {
            Files = new List<CSharpFile>();
            this.ProjectContent = new CSharpProjectContent();
            this.ProjectContent.SetAssemblyName("fake");
            this.ProjectContent = this.ProjectContent.AddAssemblyReferences(new [] { mscorlib.Value, systemCore.Value });
        }

        public void AddFile(string source)
        {
            Files.Add(new CSharpFile(this, "myfile", source));    
            this.ProjectContent = this.ProjectContent
                .AddOrUpdateFiles(Files.Select(f => f.ParsedFile));

        }

        public IProjectContent ProjectContent { get; set; }
        public string Title { get; set; }
        public List<CSharpFile> Files { get; private set; }
        public CSharpParser CreateParser()
        {
            var settings = new CompilerSettings();
            return new CSharpParser(settings);
        }
    }
}
