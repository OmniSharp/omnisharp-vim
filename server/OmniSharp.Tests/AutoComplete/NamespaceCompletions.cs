using NUnit.Framework;
using Should;

namespace OmniSharp.Tests.AutoComplete
{
    [TestFixture]
    public class NamespaceCompletions : CompletionTestBase
    {
        [Test]
        public void Should_not_break_with_empty_file()
        {
            DisplayTextFor("$").ShouldBeEmpty();
        }

        [Test]
        public void Should_complete_using1()
        {
            DisplayTextFor("u$").ShouldContain("using");
        }

        [Test]
        public void Should_complete_using2()
        {
            DisplayTextFor("us$").ShouldContainOnly("using", "unsafe");
        }

        [Test]
        public void Should_complete_using3()
        {
            DisplayTextFor("usi$").ShouldContainOnly("using");
        }

        [Test]
        public void Should_complete_using4()
        {
            DisplayTextFor("usin$").ShouldContainOnly("using");
        }

        [Test]
        public void Should_complete_using5()
        {
            DisplayTextFor("using$").ShouldContainOnly("using");
        }

        [Test]
        public void Should_complete_namespace()
        {
            DisplayTextFor("name$").ShouldContainOnly("namespace");
        }

        [Test]
        public void Should_complete_namespace2()
        {
            DisplayTextFor(
                @"using System;
n$").ShouldContain("namespace");
        }

        [Test]
        public void Should_complete_using_first()
        {
            DisplayTextFor(
                @"us$
using System;
                  ").ShouldContainOnly("using", "unsafe");
        }

        [Test]
        public void Should_complete_using_second()
        {
            DisplayTextFor(
                @"using System;
                  us$
                  ").ShouldContainOnly("using", "unsafe");
        }

        [Test]
        public void Should_complete_system()
        {
            DisplayTextFor("using $").ShouldContain("System");
        }

        [Test]
        public void Should_complete_system_only()
        {
            DisplayTextFor("using Sys$").ShouldContainOnly("System");
        }

        [Test]
        public void Should_complete_diagnostics()
        {
            DisplayTextFor("using System.$").ShouldContain("Diagnostics");
        }

        [Test]
        public void Should_complete_diagnostics_from_d()
        {
            DisplayTextFor("using System.d$").ShouldContainOnly("Deployment", "Diagnostics", "Dynamic", "Threading");
        }

        [Test]
        public void Should_complete_diagnostics_only()
        {
            DisplayTextFor("using System.di$").ShouldContain("Diagnostics");
        }
    }
}
