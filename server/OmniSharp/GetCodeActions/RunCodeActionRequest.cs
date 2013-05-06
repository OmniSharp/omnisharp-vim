using OmniSharp.Common;

namespace OmniSharp.GetCodeActions
{
    public class RunCodeActionRequest : Request
    {
        public int CodeAction { get; set; }
    }
}