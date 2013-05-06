using Should;
using NUnit.Framework;

namespace OmniSharp.Tests.TypeLookup
{
    [TestFixture]
    public class Properties
    {
        [Test]
        public void Should_LookupInt1()
        {
            @"
public class Test
{
    private int Co$unt { get; set; };
    public Test()
    {
        Count = 10;
    }
}
".LookupType().ShouldEqual("int Test.Count { get; set; }");
        }

        [Test]
        public void Should_LookupInt2()
        {
            @"
public class Test
{
    private int Count { get; set; };
    public Test()
    {
        $Count = 10;
    }
}
".LookupType().ShouldEqual("int Test.Count { get; set; }");
       }

        [Test]
        public void Should_LookupInt_static()
        {
            @"
public class Test
{
    private static int C$ount { get; set; };
    public Test()
    {
        Count = 10;
    }
}
".LookupType().ShouldEqual("static int Test.Count { get; set; }");
       }

        [Test]
        public void Should_LookupString_static()
        {
            @"
public static class ClassA
{
    public static string Name { get; set; }
}

public class Test
{
    public void Main()
    {
        string s = ClassA.Na$me;
    }
}
".LookupType().ShouldEqual("static string ClassA.Name { get; set; }");
       }

        [Test]
        public void Should_LookupInstanceString()
        {
            @"
public class Test
{
    private string Name { get; set; }
    public void Main()
    {
        var t = new Test();
        t.N$ame = ""Test""
    }
}
".LookupType().ShouldEqual("string Test.Name { get; set; }");
        }
    }
}
