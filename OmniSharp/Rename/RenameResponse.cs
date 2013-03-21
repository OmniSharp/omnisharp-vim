using System.Collections.Generic;
using OmniSharp.FindUsages;

namespace OmniSharp.Rename
{
    public class RenameResponse
    {
        public IEnumerable<ModifiedFileResponse> Changes { get; set; }
        public IEnumerable<Usage> Usages { get; set; }
    }
}