using System.Collections.Generic;
using OmniSharp.Common;

namespace OmniSharp.Build
{
    public class BuildResponse
    {
        public BuildResponse()
        {
            QuickFixes = new List<QuickFix>();
        }
        public bool Success { get; set; }
        public IEnumerable<QuickFix> QuickFixes { get; set; }
    }
}