using System.Collections.Generic;
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
            var nodes = _findUsagesHandler.FindUsageNodes(req);
            var context = OmniSharpRefactoringContext.GetContext(_bufferParser, req);
            var response = new RenameResponse();
            using (var script = new OmniSharpScript(context))
            {
                var modfiedFiles = new List<ModifiedFileResponse>();
                foreach (var node in nodes)
                {
                    script.Rename(node, req.RenameTo);
                    var modifiedFile = new ModifiedFileResponse
                        {
                            FileName = node.GetRegion().FileName,
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