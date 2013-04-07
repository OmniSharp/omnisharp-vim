using Should;
using NUnit.Framework;

namespace OmniSharp.Tests.TypeLookup
{
    [TestFixture]
    public class EmptyResults
    {
        [Test]
        public void LookupWhiteSpace()
        {
            @"
public class Test
{
 $   public void static Main()
    {
        int name = 10;
        name++;
    }
}".LookupType().ShouldEqual("");
        }

        [Test]
        public void LookupKeyword()
        {
            @"
public class Test
{
    public sta$tic void Main()
    {
        int name = 10;
        name++;
    }
}".LookupType().ShouldEqual("");
       }
 
        [Test]
        public void LookupNamespace()
        {
            @"
using Sys$tem;
public class Test
{
    public static void Main()
    {
        int name = 10;
        name++;
    }
}".LookupType().ShouldEqual("");
        }
 
    }
}
