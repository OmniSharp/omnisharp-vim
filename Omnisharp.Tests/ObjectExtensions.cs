using System.Collections;
using NUnit.Framework;

namespace Omnisharp.Tests
{
    public static class ObjectExtensions
    {
        public static void ShouldContainOnly(this IEnumerable obj, params object[] items)
        {
            CollectionAssert.AreEqual(items, obj);
        }
    }
}