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
            Projects = new Dictionary<string, IProject>();
        }
        public Dictionary<string, IProject> Projects { get; private set; }

        public CSharpFile GetFile(string filename)
        {
            return (from project in Projects.Values
                    from file in project.Files
                    where file.FileName == filename
                    select file).FirstOrDefault();
        }

        public IProject ProjectContainingFile(string filename)
        {
            return Projects.Values.FirstOrDefault(p => p.Files.Any(f => f.FileName.Equals(filename, StringComparison.InvariantCultureIgnoreCase)));
        }
    }
}
