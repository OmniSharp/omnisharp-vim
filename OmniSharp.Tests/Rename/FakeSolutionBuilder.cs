namespace OmniSharp.Tests.Rename
{
    public class FakeSolutionBuilder
    {
        private readonly FakeSolution _solution;
        private readonly FakeProject _project;

        public FakeSolutionBuilder()
        {
            _solution = new FakeSolution();
            _project = new FakeProject();
        }

        public FakeSolutionBuilder AddFile(string buffer, string fileName = "myfile")
        {
            _project.AddFile(buffer, fileName);
            return this;
        }

        public FakeSolution Build()
        {
            _solution.Projects.Add("dummyproject", _project);
            return _solution;
        }
    }
}