using System;
using System.Collections.Generic;
using System.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddReferenceProcessorFactory
    {
        private readonly ISolution _solution;
        private readonly IDictionary<Type, IReferenceProcessor> _processors; 

        public AddReferenceProcessorFactory(ISolution solution, IEnumerable<IReferenceProcessor> processors)
        {
            _solution = solution;
            _processors = processors.ToDictionary(k => k.GetType(), v => v);
        }

        public IReferenceProcessor CreateProcessorFor(AddReferenceRequest request)
        {
            if (IsProjectReference(request.Reference))
            {
                return _processors[typeof (AddProjectReferenceProcessor)];
            }

            return _processors[typeof(AddFileReferenceProcessor)];
        }

        private bool IsProjectReference(string referenceName)
        {
            return _solution.Projects.Any(p => p.FileName.Contains(referenceName));
        }
    }
}