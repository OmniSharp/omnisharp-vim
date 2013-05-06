using System.Collections.Generic;
using OmniSharp.Common;

namespace OmniSharp.FindUsages
{
    public class FindUsagesResponse
    {
        public IEnumerable<QuickFix> Usages { get; set; }
    }
}