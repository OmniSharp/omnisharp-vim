using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.GotoImplementation
{
    public class GotoImplementationModule : NancyModule
    {
        public GotoImplementationModule(GotoImplementationProvider provider)
        {
            Post["/findimplementations"] = x =>
                {
                    var req = this.Bind<GotoImplementationRequest>();
                    var res = provider.FindDerivedMembers(req);
                    return Response.AsJson(res);
                };
        }
    }
}