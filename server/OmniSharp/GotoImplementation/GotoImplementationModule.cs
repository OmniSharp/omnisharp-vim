using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.GotoImplementation
{
    public class GotoImplementationModule : NancyModule
    {
        public GotoImplementationModule(GotoImplementationHandler handler)
        {
            Post["/findimplementations"] = x =>
                {
                    var req = this.Bind<GotoImplementationRequest>();
                    var res = handler.FindDerivedMembers(req);
                    return Response.AsJson(res);
                };
        }
    }
}