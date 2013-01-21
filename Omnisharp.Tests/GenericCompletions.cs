using System.Linq;
using NUnit.Framework;

namespace Omnisharp.Tests
{
    [TestFixture]
    public class GenericCompletions 
    {
        [Test]
        public void Should_complete_generic_completion()
        {
         var completions = new CompletionsSpecBase().GetCompletions(
@"using System.Collections.Generic;
public class Class1 {
    public Class1()
    {
        
        var l = new List<string>();
        l.ad$
    }
}");

                completions.Select(c => c.DisplayText).ShouldContainOnly(
                    "Add", 
                    "AddRange");
        }

        [Test]
        public void Should_complete_extension_method()
        {
            var completions = new CompletionsSpecBase().GetCompletions(
@"using System.Collections.Generic;
using System.Linq;

public class A {
    public A()
    {
        var l = new List<string>();
        l.ad$
    }
}");

                completions.Select(c => c.DisplayText).ShouldContainOnly(
                    "Add", 
                    "AddRange");
        }
    }
}
