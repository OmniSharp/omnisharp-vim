using OmniSharp.Requests;

namespace OmniSharp.FindUsages
{
    public class FindUsagesRequest : Request
    {
        public int Line { get; set; }
        public int Column { get; set; }
    }
}