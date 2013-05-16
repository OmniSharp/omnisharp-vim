using NUnit.Framework;

namespace OmniSharp.Tests.AutoComplete
{
    [TestFixture]
    public class GenericCompletions : CompletionTestBase
    {
        [Test]
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

                public static string MyExtension(this string s, int i)
                {
                    return s;
                }
            }
            ").ShouldContainOnly("string MyExtension()", "string MyExtension(int i)");
        }

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
                .ShouldContain(
                    "void Add(string item)",
                    "void AddRange(IEnumerable<string> collection)"); 
        }
    }
}
