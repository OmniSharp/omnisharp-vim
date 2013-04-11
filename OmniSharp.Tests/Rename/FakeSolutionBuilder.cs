using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.Tests.Rename
{
    public class FakeSolutionBuilder
    {
        private readonly FakeSolution _solution;
        private readonly FakeProject _project;
        private readonly List<FakeProject> _projects = new List<FakeProject>();

        private int projectCount = 1;
        public FakeSolutionBuilder()
        {
            _solution = new FakeSolution();
            _project = new FakeProject("Project" + projectCount++);
            _projects.Add(_project);
        }

        public FakeSolutionBuilder AddProject()
        {
            var newProject = new FakeProject("Project" + projectCount++);
			
            foreach (var project in _projects)
            {
                // each project references the ones that came before it.
                newProject.ProjectContent.AddAssemblyReferences(new ProjectReference(project.Name));
            }
            _projects.Add(newProject);

            return this;
        }

        public FakeSolutionBuilder AddFile(string buffer, string fileName = "myfile")
        {
            _projects.Last().AddFile(buffer, fileName);
            return this;
        }

        public FakeSolution Build()
        {
            foreach(var project in _projects)
                _solution.Projects.Add(project);
            return _solution;
        }
    }
}
