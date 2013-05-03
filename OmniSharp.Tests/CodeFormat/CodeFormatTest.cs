using NUnit.Framework;
using OmniSharp.CodeFormat;
using OmniSharp.Common;
using Should;

namespace OmniSharp.Tests.CodeFormat
{
    [TestFixture]
    class CodeFormatTest
    {
        [Test]
        public void Should_format_code()
        {
            string code =
@"public class Test {
}";

            string expected =
@"public class Test
{
}";
            var handler = new CodeFormatHandler();
            var buffer = handler.Format(new Request {Buffer = code}).Buffer;
            buffer.ShouldEqual(expected);
        }
    }
}
