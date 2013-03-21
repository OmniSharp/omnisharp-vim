using System.Collections.Generic;
using System.IO;
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
            IEnumerable<AstNode> nodes = _findUsagesHandler.FindUsageNodes(req).ToArray();
            
            var response = new RenameResponse();

            var modfiedFiles = new List<ModifiedFileResponse>();
            response.Changes = modfiedFiles;

            foreach (IGrouping<string, AstNode> groupedNodes in nodes.GroupBy(n => n.GetRegion().FileName.FixPath()))
            {
                string fileName = groupedNodes.Key;
                OmniSharpRefactoringContext context;
                if (groupedNodes.Key != req.FileName)
                {
                    var file = _solution.GetFile(fileName);
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
                    = fileName,
                    Buffer = modifiedBuffer
                };
                modfiedFiles.Add(modifiedFile);
                response.Changes = modfiedFiles;
                _bufferParser.ParsedContent(modifiedBuffer, fileName);
                _solution.GetFile(fileName).Update(modifiedBuffer);
            }

            if (nodes.Any())
            {
                

                var usages = nodes.Select(node => new Usage
                {
                    FileName = node.GetRegion().FileName,
                    Text = node.Preview(_solution.GetFile(node.GetRegion().FileName)).Replace("'", "''"),
                    Line = node.StartLocation.Line,
                    Column = node.StartLocation.Column,
                });
                response.Usages = usages;
            }
            return response;
        }
    }
}