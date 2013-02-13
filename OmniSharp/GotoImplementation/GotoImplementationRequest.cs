using OmniSharp.Requests;

namespace OmniSharp.GotoImplementation
{
    public class GotoImplementationRequest : Request
    {
        public int Line { get; set; }
        public int Column { get; set; }
    }
}