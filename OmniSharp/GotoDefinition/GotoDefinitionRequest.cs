using OmniSharp.Requests;

namespace OmniSharp.GotoDefinition
{
    public class GotoDefinitionRequest : Request
    {
        public int Line { get; set; }
        public int Column { get; set; }
    }
}