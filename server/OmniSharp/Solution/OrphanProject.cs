using System;
using System.Collections.Generic;
using System.Xml.Linq;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.Solution
{
    /// <summary>
    /// Placeholder that can be used for files that don't belong to a project.
    /// </summary>
    public class OrphanProject : IProject
    {
        public string Title { get; private set; }
        public List<CSharpFile> Files { get; private set; }
        public List<IAssemblyReference> References { get; set; }
        public IProjectContent ProjectContent { get; set; }
        public string FileName { get; private set; }
        public Guid ProjectId { get; private set; }

        public void AddReference(IAssemblyReference reference)
        {
            References.Add(reference);
        }

        public void AddReference(string reference)
        {
            AddReference(CSharpProject.LoadAssembly(reference));
        }

        private CSharpFile _file;

        public OrphanProject(ISolution solution)
        {
            Title = "Orphan Project";
            _file = new CSharpFile(this, "dummy_file", "");
            Files = new List<CSharpFile>();
            Files.Add(_file);

            ProjectId = Guid.NewGuid();

            string mscorlib = CSharpProject.FindAssembly(CSharpProject.AssemblySearchPaths, "mscorlib");
            ProjectContent = new CSharpProjectContent()
                .SetAssemblyName("OrphanProject")
                .AddAssemblyReferences(CSharpProject.LoadAssembly(mscorlib));
        }

        public CSharpFile GetFile(string fileName)
        {
            return _file;
        }

        public CSharpParser CreateParser()
        {
            return new CSharpParser();
        }

        public XDocument AsXml()
        {
            throw new NotImplementedException();
        }

        public void Save(XDocument project)
        {
            throw new NotImplementedException();
        }

    }
}
