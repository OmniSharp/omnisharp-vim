using System.Linq;
using NUnit.Framework;

namespace Omnisharp.Tests
{
    public class DerivedTypeCompletions
    {
        [Test]
        public void Should_complete_derived_types()
        {
            var completions = new CompletionsSpecBase().GetCompletions(
@"public class A {
    public A() 
    {
        int n;
        n.GetHashCode$;
    }
}");

            completions.Select(c => c.DisplayText).ShouldContainOnly("GetHashCode()");
        }
    }
}