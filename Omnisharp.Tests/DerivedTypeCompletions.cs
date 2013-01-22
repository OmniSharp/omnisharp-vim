using NUnit.Framework;

namespace Omnisharp.Tests
{
    public class DerivedTypeCompletions : CompletionTestBase
    {
        [Test]
        public void Should_complete_derived_types()
        {
            DisplayTextFor(
@"public class A {
    public A() 
    {
        int n;
        n.GetHashCode$;
    }
}").ShouldContainOnly("GetHashCode()");
        }
    }
}