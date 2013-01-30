using System.Collections.Generic;
using System.Linq;

namespace Omnisharp.Tests.CompletionTests
{
    public class CompletionTestBase
    {
        protected IEnumerable<string> DisplayTextFor(string input)
        {
            return new CompletionsSpecBase().GetCompletions(input).Select(c => c.DisplayText);
        }

        protected IEnumerable<string> CompletionsFor(string input)
        {
            return new CompletionsSpecBase().GetCompletions(input).Select(c => c.CompletionText);
        }
    }
}