using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Resolver;
using OmniSharp.FindUsages;
using OmniSharp.Parser;
using OmniSharp.Refactoring;
using OmniSharp.Solution;

namespace OmniSharp.Rename
{
    public class RenameHandler
    {
        private readonly ISolution _solution;
        private readonly BufferParser _bufferParser;
        private readonly FindUsagesHandler _findUsagesHandler;

        public RenameHandler(ISolution solution, BufferParser bufferParser)
        {
            _solution = solution;
            _bufferParser = bufferParser;
            _findUsagesHandler = new FindUsagesHandler(bufferParser, solution);
        }

        public RenameResponse Rename(RenameRequest req)
        {
            IEnumerable<AstNode> nodes = _findUsagesHandler.FindUsageNodes(req);
            var response = new RenameResponse();

            var modfiedFiles = new List<ModifiedFileResponse>();
            response.Changes = modfiedFiles;

            foreach (IGrouping<string, AstNode> groupedNodes in nodes.GroupBy(n => n.GetRegion().FileName))
            {
                OmniSharpRefactoringContext context;
                if (groupedNodes.Key != req.FileName)
                {
                    var file = _solution.GetFile(groupedNodes.Key);
                    var bufferParser = new BufferParser(_solution);
                    var content = bufferParser.ParsedContent(file.Document.Text, file.FileName);
                    var resolver = new CSharpAstResolver(content.Compilation, content.SyntaxTree, content.UnresolvedFile);
                    context = new OmniSharpRefactoringContext(file.Document, resolver);
                }
                else
                {
                    context = OmniSharpRefactoringContext.GetContext(_bufferParser, req);
                }
                string modifiedBuffer = null;
                foreach (var node in groupedNodes)
                {
                    using (var script = new OmniSharpScript(context))
                    {
                        script.Rename(node, req.RenameTo);
                        modifiedBuffer = script.CurrentDocument.Text;
                    }
                }

                var modifiedFile = new ModifiedFileResponse
                {
                    FileName
                    = groupedNodes.Key,
                    Buffer = modifiedBuffer
                };
                modfiedFiles.Add(modifiedFile);
                response.Changes = modfiedFiles;
            }
            return response;
        }
    }
}