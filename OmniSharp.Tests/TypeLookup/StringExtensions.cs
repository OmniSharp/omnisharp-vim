using System;
using OmniSharp.Parser;
using OmniSharp.TypeLookup;

namespace OmniSharp.Tests.TypeLookup
{
    public static class StringExtensions
    {
        public static string LookupType(this string editorText)
        {
            int cursorOffset = editorText.IndexOf("$", StringComparison.Ordinal);
            var cursorPosition = TestHelpers.GetLineAndColumnFromIndex(editorText, cursorOffset);
            editorText = editorText.Replace("$", "");

            var solution = new FakeSolution();
            var project = new FakeProject();
            project.AddFile(editorText);
            solution.Projects.Add("dummyproject", project);

            var handler = new TypeLookupHandler(new BufferParser(solution));
            var request = new TypeLookupRequest()
                {
                    Buffer = editorText,
                    FileName = "myfile",
                    Line = cursorPosition.Item1,
                    Column = cursorPosition.Item2,
                };

            return handler.GetTypeLookupResponse(request).Type;
        }
    }
}
