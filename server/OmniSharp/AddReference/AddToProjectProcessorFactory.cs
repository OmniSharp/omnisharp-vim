using System.Collections.Generic;
using System.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddToProjectProcessorFactory
    {
        private readonly ISolution _solution;
        private readonly IList<IAddToProjectProcessor> _processors;

        public AddToProjectProcessorFactory(ISolution solution, IList<IAddToProjectProcessor> processors)
        {
            _solution = solution;
            _processors = processors;
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