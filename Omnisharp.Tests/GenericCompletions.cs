using System.Linq;
using NUnit.Framework;

namespace Omnisharp.Tests
{
    [TestFixture]
    public class GenericCompletions : CompletionTestBase
    {
        [Test]
        public void Should_complete_generic_completion()
        {
            DisplayTextFor(
            @"using System.Collections.Generic;
            public class Class1 {
                public Class1()
                {
        
                    var l = new List<string>();
                    l.ad$
                }
            }")
              .ShouldContainOnly(
                    "Add(string item)",
                    "AddRange(IEnumerable collection)"); //TODO: IEnumerable<string>
        }

        [Test, Ignore("wip")]
        public void Should_complete_extension_method()
        {
            DisplayTextFor(
            @"using System.Collections.Generic;
            using System.Linq;

            public class A {
                public A()
                {
                    string s;
                    s.MyEx$
                }
            }

            public static class StringExtensions
            {
                public static string MyExtension(this string s)
                {
                    return s;
                }
            }
            ").ShouldContainOnly("MyExtension()");
        }
    }
}
