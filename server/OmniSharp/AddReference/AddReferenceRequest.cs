using OmniSharp.Common;

namespace OmniSharp.AddReference
{
    public class AddReferenceRequest : Request
    {
        public string CurrentProject { get; set; }
        public string Reference { get; set; }
    }
}