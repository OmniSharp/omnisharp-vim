using System.Collections.Generic;
using System.Linq;
using ICSharpCode.NRefactory.CSharp;
using OmniSharp.FindUsages;
using OmniSharp.Parser;
using OmniSharp.Refactoring;

namespace OmniSharp.Rename
{
    public class RenameHandler
    {
        private readonly BufferParser _bufferParser;
        private readonly FindUsagesHandler _findUsagesHandler;

        public RenameHandler(BufferParser bufferParser, FindUsagesHandler findUsagesHandler)
        {
            _bufferParser = bufferParser;
            _findUsagesHandler = findUsagesHandler;
        }

        public RenameResponse Rename(RenameRequest req)
        {
            IEnumerable<AstNode> nodes = _findUsagesHandler.FindUsageNodes(req);
            var context = OmniSharpRefactoringContext.GetContext(_bufferParser, req);
            var response = new RenameResponse();
            using (var script = new OmniSharpScript(context))
            {
                var modfiedFiles = new List<ModifiedFileResponse>();
                foreach (IGrouping<string, AstNode> groupedNodes in nodes.GroupBy(n => n.GetRegion().FileName))
                {
                    foreach (var node in groupedNodes)
                    {
                        script.Rename(node, req.RenameTo);
                    }
                    
                    var modifiedFile = new ModifiedFileResponse
                        {
                            FileName = groupedNodes.Key,
                            Buffer = script.CurrentDocument.Text
                        };
                    modfiedFiles.Add(modifiedFile);
                }
                response.Changes = modfiedFiles;
            }
            return response;
        }
    }
}