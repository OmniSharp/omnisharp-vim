using ICSharpCode.NRefactory;

namespace OmniSharp.Tests
{
    public static class TestHelpers
    {
        public static TextLocation GetLineAndColumnFromDollar(string text)
        {
            return GetLineAndColumnFromIndex(text, text.IndexOf("$"));
        }

        public static TextLocation GetLineAndColumnFromIndex(string text, int index)
        {
            int lineCount = 1, lastLineEnd = -1;
            for (int i = 0; i < index; i++)
                if (text[i] == '\n')
                {
                    lineCount++;
                    lastLineEnd = i;
                }

            return new TextLocation(lineCount, index - lastLineEnd);
        }
    }
}
