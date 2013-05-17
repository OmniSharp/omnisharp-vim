using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddReferenceHandler
    {
        private readonly ISolution _solution;
        private readonly AddToProjectProcessorFactory _addToProjectProcessorFactory;

        public AddReferenceHandler(ISolution solution, AddToProjectProcessorFactory addToProjectProcessorFactory)
        {
            _solution = solution;
            _addToProjectProcessorFactory = addToProjectProcessorFactory;
        }

        public AddReferenceResponse AddReference(AddReferenceRequest request)
        {
            var project = _solution.ProjectContainingFile(request.FileName);
           
            var processor = _addToProjectProcessorFactory.CreateProcessorFor(request);

            return processor.AddReference(project, request.Reference);
           
        }
    }
}