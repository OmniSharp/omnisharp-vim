using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.GetCodeActions
{
    public class RunCodeActionModule : NancyModule
    {
        public RunCodeActionModule(GetCodeActionsHandler codeActionsHandler)
        {
            Post["/runcodeaction"] = x =>
                {
                    var req = this.Bind<RunCodeActionRequest>();
                    var res = codeActionsHandler.RunCodeAction(req);
                    return Response.AsJson(res);
                };
        }
    }
}