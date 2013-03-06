using System.Collections.Generic;

namespace OmniSharp.SyntaxErrors
{
    public class SyntaxErrorsResponse
    {
        public IEnumerable<Error> Errors { get; set; }
    }
}
