using Should;
using NUnit.Framework;

namespace OmniSharp.Tests.TypeLookup
{
    [TestFixture]
    public class Methods
    {
        [Test]
        public void Should_Lookup_ReturnString_NoArgs()
        {
            @"
public class Test
{
    public string MethodA()
    {
        return ""Test"";
    }

    public static void Main()
    {
        var t = new Test();
        t.M$ethodA();
    }
}
".LookupType().ShouldEqual("string Test.MethodA();");
        }

        [Test]
        public void Should_LookupStatic_ReturnTest_OneArg()
        {
            @"
public class Test
{
    public static Test Create(string s)
    {
        return new Test();
    }

    public static void Main()
    {
        var t = Creat$e();
    }
}
".LookupType().ShouldEqual("static Test Test.Create(string s);");
        }

        [Test]
        public void Should_LookupConstructor_NoArgs()
        {
            @"
public class Test
{

    public static void Main()
    {
        var t = new Te$st();
    }
}
".LookupType().ShouldEqual("Test.Test();");
        }
    }
}
