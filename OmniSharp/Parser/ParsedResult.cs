using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.TypeSystem;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.Parser
{
    public class ParsedResult
    {
        public ICompilation Compilation { get; set; }
        public IProjectContent ProjectContent { get; set; }
        public CSharpUnresolvedFile UnresolvedFile { get; set; }
        public SyntaxTree SyntaxTree { get; set; }
    }
}