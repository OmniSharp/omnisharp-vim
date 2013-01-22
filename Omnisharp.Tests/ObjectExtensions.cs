using System.Collections.Generic;
using System.Linq;
using Should;

namespace Omnisharp.Tests
{
    public static class ObjectExtensions
    {
        public static void ShouldContainOnly(this IEnumerable<object> actual, params object[] expected)
        {
            actual.SequenceEqual(expected);
            //actual.ShouldContain(expected);
            actual.Count().ShouldEqual(expected.Count(), "Expected " + expected.Count() + " items, got " + actual.Count());

        }
    }
}