using System;
using ICSharpCode.NRefactory.CSharp;
using OmniSharp.Solution;

namespace OmniSharp.FindUsages
{
    public static class AstNodeExtensions
    {
        public static string Preview(this AstNode node, CSharpFile file)
        {
            var location = node.StartLocation;
            var offset = file.Document.GetOffset(location.Line, location.Column);
            var line = file.Document.GetLineByNumber(location.Line);
            if (line.Length < 50)
            {
                return file.Document.GetText(line.Offset, line.Length);
            }

            var start = Math.Max(line.Offset, offset - 60);
            var end = Math.Min(line.EndOffset, offset + 60);

            return "..." + file.Document.GetText(start, end - start).Trim() + "...";
        }
    }
}