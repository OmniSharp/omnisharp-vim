using Should;
using NUnit.Framework;

namespace OmniSharp.Tests.TypeLookup
{
    [TestFixture]
    public class LocalVariables
    {
        [Test]
        public void Should_LookupInt()
        {
            @"
public class Test
{
    public static void Main()
    {
        int na$me = 10;
    }
}
".LookupType().ShouldEqual("int name");
        }

        [Test]
        public void Should_LookupInt_From_var1()
        {
            @"
public class Test
{
    public static void Main()
    {
        var na$me = 10;
    }
}
".LookupType().ShouldEqual("int name");
       }
 
        [Test]
        public void Should_LookupInt_From_var2()
        {
            @"
public class Test
{
    public static void Main()
    {
        va$r name = 10;
    }
}
".LookupType().ShouldEqual("int");
        }
 
        [Test]
        public void Should_LookupInt_From_var3()
        {
            @"
public class Test
{
    public static void Main()
    {
        var name = 10;
        nam$e++;
    }
}
".LookupType().ShouldEqual("int name");
        }
 
        [Test, Ignore("wip")]
        public void Should_LookupTest_From_var()
        {
            @"
public class Test
{
    public static void Main()
    {
        va$r name = new Test();
    }
}
".LookupType().ShouldEqual("Test");
        }
 
        [Test]
        public void Should_LookupDelegate()
        {
            @"
public delegate void Run();
public class Test
{
    public static void Main()
    {
        Run run = Main;
        r$un();
    }
}
".LookupType().ShouldEqual("Run run");
        }

        [Test]
        public void Should_LookupUnknown()
        {
            @"
public class Test
{
    public void Main()
    {
        FakeType ty$pe;
        type = null;
    }
}
".LookupType().ShouldEqual("Unknown Type");
        }
    }
}
