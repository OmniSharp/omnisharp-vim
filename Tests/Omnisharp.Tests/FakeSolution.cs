using System.Collections.Generic;
using OmniSharp.Solution;

namespace Omnisharp.Tests
{
    public class FakeSolution : ISolution
    {
        public FakeSolution()
        {
            Projects = new Dictionary<string, IProject>();
        }
        public Dictionary<string, IProject> Projects { get; set; }
    }
}