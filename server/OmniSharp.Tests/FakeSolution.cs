using System;
using System.Collections.Generic;
using System.Linq;
using OmniSharp.Solution;

namespace OmniSharp.Tests
{
    public class FakeSolution : ISolution
    {
        public FakeSolution()
        {
            Projects = new List<IProject>();
        }

        public FakeSolution(string filename) : this()
        {
            FileName = filename;
        }

        public List<IProject> Projects { get; private set; }
        public string FileName { get; private set; }

        public CSharpFile GetFile(string filename)
        {
            return (from project in Projects
                    from file in project.Files
                    where file.FileName == filename
                    select file).FirstOrDefault();
        }

        public IProject ProjectContainingFile(string filename)
        {
            return Projects.FirstOrDefault(p => p.Files.Any(f => f.FileName.Equals(filename, StringComparison.InvariantCultureIgnoreCase)));
        }

        public void Reload()
        {
            throw new NotImplementedException();
        }

        public void Terminate()
        {
            throw new NotImplementedException();
        }
    }
}
