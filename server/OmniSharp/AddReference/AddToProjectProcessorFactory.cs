using System.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddToProjectProcessorFactory
    {
        private readonly ISolution _solution;

        public AddToProjectProcessorFactory(ISolution solution)
        {
            _solution = solution;
        }

        public IAddToProjectProcessor CreateProcessorFor(AddReferenceRequest request)
        {
            if (IsProjectReference(request.Reference))
            {
                return new AddProjectReferenceProcessor(_solution);
            }

            return null;
        }

        private bool IsProjectReference(string referenceName)
        {
            return _solution.Projects.Any(p => p.FileName.Contains(referenceName));
        }
    }
}