using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.GotoDefinition
{
    public class GotoDefinitionModule : NancyModule
    {
        public GotoDefinitionModule(GotoDefinitionHandler gotoDefinitionHandler)
        {
            Post["/gotodefinition"] = x =>
                {
                    var req = this.Bind<GotoDefinitionRequest>();
                    var res = gotoDefinitionHandler.GetGotoDefinitionResponse(req);
                    return Response.AsJson(res);
                };
        }
    }
}