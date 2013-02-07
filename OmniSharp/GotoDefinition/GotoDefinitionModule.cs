using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.GotoDefinition
{
    public class GotoDefinitionModule : NancyModule
    {
        public GotoDefinitionModule(GotoDefinitionProvider gotoDefinitionProvider)
        {
            Post["/gotodefinition"] = x =>
                {
                    var req = this.Bind<GotoDefinitionRequest>();
                    var res = gotoDefinitionProvider.GetGotoDefinitionResponse(req);
                    return Response.AsJson(res);
                };
        }
    }
}