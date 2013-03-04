using OmniSharp.Requests;

namespace OmniSharp.AutoComplete
{
    public class AutoCompleteRequest : Request
    {
        public string WordToComplete { get; set; }
    }
}
