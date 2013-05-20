using Nancy;
using OmniSharp.Solution;

namespace OmniSharp.StopServer
{
    public class StopServerModule : NancyModule
    {
        public StopServerModule(ISolution solution)
        {
            Post["/stopserver"] = x =>
                {
                    solution.Terminate();
                    return Response.AsJson(true);
                };
        }
    }
}
