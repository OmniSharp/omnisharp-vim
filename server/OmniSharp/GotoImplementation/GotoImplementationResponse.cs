using System.Collections.Generic;

namespace OmniSharp.GotoImplementation
{
    public class GotoImplementationResponse
    {
        public IEnumerable<Location> Locations = new List<Location>();
    }
}