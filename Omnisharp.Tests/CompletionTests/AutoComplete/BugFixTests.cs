using System.Linq;
using NUnit.Framework;
using Should;

namespace Omnisharp.Tests.CompletionTests.AutoComplete
{
    public class BugFixTests : CompletionTestBase
    {
        [Test]
        public void Should_complete_to_string()
        {
            DisplayTextFor(
                @"public class A {
    public A() 
    {
        int n;
        n.T$;
    }
}").First().ShouldEqual("ToString()");
        }
    }
}