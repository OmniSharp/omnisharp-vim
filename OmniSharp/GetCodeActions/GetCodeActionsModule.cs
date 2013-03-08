using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.GetCodeActions
{
    public class GetCodeActionsModule : NancyModule
    {
        public GetCodeActionsModule(GetCodeActionsHandler gotoDefinitionHandler)
        {
            Post["/getcodeactions"] = x =>
                {
                    var req = this.Bind<Requests.Request>();
                    var res = gotoDefinitionHandler.GetCodeActions(req);
                    return Response.AsJson(res);
                };
        }
    }
}