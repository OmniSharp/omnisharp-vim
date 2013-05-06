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

        public IAssembly Resolve(ITypeResolveContext context)
        {
            var project = _solution.Projects.Single(p => string.Equals(p.Title, _projectTitle, StringComparison.OrdinalIgnoreCase));
            return project.ProjectContent.Resolve(context);
        }
    }
}
