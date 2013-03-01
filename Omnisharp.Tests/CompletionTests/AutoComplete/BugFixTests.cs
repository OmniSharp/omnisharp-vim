using System.Linq;
using NUnit.Framework;
using Should;

namespace Omnisharp.Tests.CompletionTests.AutoComplete
{
    [TestFixture]
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

        [Test]
        public void Should_complete_to_Process1More()
        {
            DisplayTextFor(
                    @"
public class MyClass
{
    public static int Process1More()
    {
        return 10;
    }

    public static void Main()
    {
        var i = Process1M$
    }
}").ShouldContain("Process1More()");
        }
    }
}
