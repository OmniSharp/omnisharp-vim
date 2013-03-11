using OmniSharp.Requests;

namespace OmniSharp.GetCodeActions
{
    public class RunCodeActionRequest : Request
    {
        public string CodeAction { get; set; }
    }
}