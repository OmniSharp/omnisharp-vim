using System.Collections.Generic;

namespace OmniSharp.Rename
{
    public class RenameResponse
    {
        public IEnumerable<ModifiedFileResponse> Changes { get; set; }
    }
}