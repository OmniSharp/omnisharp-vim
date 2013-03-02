using OmniSharp.Requests;

namespace OmniSharp.AutoComplete
{
    public class AutoCompleteRequest : Request
    {
        public int Line { get; set; }
        public int Column { get; set; }
        public string WordToComplete { get; set; }
    }
}
