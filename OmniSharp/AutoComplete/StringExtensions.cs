using System.Linq;

namespace OmniSharp.AutoComplete
{
    public static class StringExtensions
    {
        public static bool IsValidCompletionFor(this string completion, string partial)
        {
            return completion.ToLower().StartsWith(partial.ToLower()) || IsCamelCaseMatch(completion, partial);
        }

        private static bool IsCamelCaseMatch(this string completion, string partial)
        {
            return new string(completion.Where(c => c >= 'A' && c <= 'Z').ToArray()).StartsWith(partial.ToUpper());
        }
    }
}
