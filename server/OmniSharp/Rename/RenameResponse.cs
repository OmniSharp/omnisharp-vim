using System.Collections.Generic;

namespace OmniSharp.Rename
{
    public class RenameResponse
    {
        public RenameResponse()
        {
            Changes = new List<ModifiedFileResponse>();
        }
        public IEnumerable<ModifiedFileResponse> Changes { get; set; }
    }
}