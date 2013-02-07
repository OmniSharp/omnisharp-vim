using OmniSharp.Requests;

namespace OmniSharp.AutoComplete
{
    public class AutocompleteRequest : Request
    {
        public string WordToComplete { get; set; }
    }
}