using NUnit.Framework;
using Should;

namespace OmniSharp.Tests.AutoComplete
{
    [TestFixture]
    public class ConstructorParameterCompletions : CompletionTestBase
    {
        [Test]
        public void Should_return_all_constructors()
        {
            DisplayTextFor(
                @"public class MyClass {
                            public MyClass() {}
                            public MyClass(int param) {}
                            public MyClass(string param) {}
                        }

                        public class Class2 {
                            public Class2()
                            {
                                var c = new My$
                            }
                        }")
                .ShouldContainOnly(
                    "MyClass()",
                    "MyClass(int param)",
                    "MyClass(string param)");
        }

        [Test]
        public void Should_return_all_constructors_using_camel_case_completions()
        {
            DisplayTextFor(
                @"  public class MyClassA {
                        public MyClassA() {}
                        public MyClassA(int param) {}
                        public MyClassA(string param) {}
                    }

                    public class Class2 {
                        public Class2()
                        {
                            var c = new mca$
                        }
                    }")
                .ShouldContainOnly(
                    "MyClassA()",
                    "MyClassA(int param)",
                    "MyClassA(string param)");
        }

        [Test]
        public void Should_return_no_completions()
        {
            DisplayTextFor(
                @"  public class MyClassA {
                        public MyClassA() {}
                        public MyClassA(int param) {}
                        public MyClassA(string param) {}
                    }

                    public class Class2 {
                        public Class2()
                        {
                            var c = new zzz$
                        }
                    }").ShouldBeEmpty();
        }

        [Test]
        public void Should_not_return_ctor_for_system_diagnostics()
        {
            DisplayTextFor(
                @"  public class MyClass {
                            public MyClass() {
                                System.Diagnostics.$
                            }
                        }").ShouldNotContain(".ctor");
        }

        [Test]
        public void Should_not_close_parenthesis_for_constructor_with_parameter()
        {
            CompletionsFor(
                @"public class MyClass {
                    public MyClass(int param) {}
                }

                public class Class2 {
                    public Class2()
                    {
                        var c = new My$
                    }
                }")
                .ShouldContainOnly("MyClass(");
        }

        [Test]
        public void Should_close_parentheses_for_constructor_without_parameter()
        {
            CompletionsFor(
                @"public class MyClass {
                    public MyClass() {}
                }

                public class Class2 {
                    public Class2()
                    {
                        var c = new My$
                    }
                }")
                .ShouldContainOnly("MyClass()");
        }
    }
}
