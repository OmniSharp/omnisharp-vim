using System.Collections.Generic;

namespace OmniSharp.FindUsages
{
    public class FindUsagesResponse
    {
        public IEnumerable<Usage> Usages { get; set; }
    }
}