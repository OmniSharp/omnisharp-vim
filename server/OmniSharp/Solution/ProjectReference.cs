using System;
using System.Linq;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.Solution
{
    public class ProjectReference : IAssemblyReference
    {
        readonly ISolution _solution;
        readonly string _projectTitle;

        public ProjectReference(ISolution solution, string projectTitle)
        {
            _solution = solution;
            _projectTitle = projectTitle;
        }

        public string ProjectTitle { get { return _projectTitle; } }

        public IAssembly Resolve(ITypeResolveContext context)
        {
            var project = _solution.Projects.FirstOrDefault(p => string.Equals(p.Title, _projectTitle, StringComparison.OrdinalIgnoreCase));
            if (project != null) 
                return project.ProjectContent.Resolve(context);
            return null;
        }
    }
}
