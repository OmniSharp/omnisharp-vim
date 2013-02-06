using Nancy;
using Nancy.ModelBinding;
using OmniSharp.AutoComplete;
using OmniSharp.Requests;

namespace OmniSharp.Modules
{
    public class GotoDefinitionModule : NancyModule
    {
        public GotoDefinitionModule(CompletionProvider completionProvider)
        {
            Post["/gotodefinition"] = x =>
                {
                    var req = this.Bind<GotoDefinitionRequest>();
                    var res = completionProvider.ResolveAtLocation(req);
                    return Response.AsJson(res);
                };
        }
    }
}