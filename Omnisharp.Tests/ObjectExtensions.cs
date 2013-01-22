using System.Collections.Generic;
using NUnit.Framework;

namespace Omnisharp.Tests
{
    public static class ObjectExtensions
    {
        public static void ShouldContainOnly(this IEnumerable<string> actual, params string[] expected)
        {
            CollectionAssert.AreEqual(expected, actual);
        }
    }
}