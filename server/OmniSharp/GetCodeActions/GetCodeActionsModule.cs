using Nancy;
using Nancy.ModelBinding;
using Request = OmniSharp.Common.Request;

namespace OmniSharp.GetCodeActions
{
    public class GetCodeActionsModule : NancyModule
    {
        public GetCodeActionsModule(GetCodeActionsHandler gotoDefinitionHandler)
        {
            Post["/getcodeactions"] = x =>
                {
                    var req = this.Bind<Request>();
                    var res = gotoDefinitionHandler.GetCodeActions(req);
                    return Response.AsJson(res);
                };
        }
    }
}