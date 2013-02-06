namespace OmniSharp.Requests
{
    public class GotoDefinitionRequest : Request
    {
        public int Line { get; set; }
        public int Column { get; set; }
    }
}