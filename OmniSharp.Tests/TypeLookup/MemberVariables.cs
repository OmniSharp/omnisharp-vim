using Should;
using NUnit.Framework;

namespace OmniSharp.Tests.TypeLookup
{
    [TestFixture]
    public class MemberVariables
    {
        [Test]
        public void Should_LookupInt1()
        {
            @"
public class Test
{
    private int _$i;
    public Test()
    {
        _i = 10;
    }
}
".LookupType().ShouldEqual("int Test._i;");
        }

        [Test]
        public void Should_LookupInt2()
        {
            @"
public class Test
{
    private int _i;
    public Test()
    {
        _$i = 10;
    }
}
".LookupType().ShouldEqual("int Test._i;");
       }
 
        [Test]
        public void Should_LookupInt_static()
        {
            @"
public class Test
{
    private static int _i;
    public Test()
    {
        _$i = 10;
    }
}
".LookupType().ShouldEqual("static int Test._i;");
       }

        [Test]
        public void Should_LookupString_static()
        {
            @"
public static class ClassA
{
    public static string Name = ""Name"";
}

public class Test
{
    public void Main()
    {
        string s = ClassA.Na$me;
    }
}
".LookupType().ShouldEqual("static string ClassA.Name;");
       }

        [Test]
        public void Should_LookupInstanceString()
        {
            @"
public class Test
{
    private string _name;
    public void Main()
    {
        var t = new Test();
        t._n$ame = ""Test""
    }
}
".LookupType().ShouldEqual("string Test._name;");
        }

        [Test]
        public void Should_LookupUnknown()
        {
            @"
public class Test
{
    private String _name;
    public void Main()
    {
        var t = new Test();
        t._n$ame = ""Test""
    }
}
".LookupType().ShouldEqual("Unknown Type: String");
        }
    }
}
