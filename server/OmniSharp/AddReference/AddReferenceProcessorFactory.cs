using System.Collections.Generic;
using System.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddReferenceProcessorFactory
    {
        private readonly ISolution _solution;
        readonly IEnumerable<IReferenceProcessor> _processors;

        public AddReferenceProcessorFactory(ISolution solution, IEnumerable<IReferenceProcessor> processors)
        {
            _solution = solution;
            _processors = processors;
        }

        public IReferenceProcessor CreateProcessorFor(AddReferenceRequest request)
        {
            if (IsProjectReference(request.Reference))
            {
                return _processors.First(p => p.GetType() == typeof (AddProjectReferenceProcessor));
            }

            return null;
        }

        private bool IsProjectReference(string referenceName)
        {
            return _solution.Projects.Any(p => p.FileName.Contains(referenceName));
        }
    }
}