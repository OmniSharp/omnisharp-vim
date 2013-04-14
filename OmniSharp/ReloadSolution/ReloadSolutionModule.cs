using Nancy;
using OmniSharp.Solution;

namespace OmniSharp.ReloadSolution
{
    public class ReloadSolutionModule : NancyModule
    {
        public ReloadSolutionModule(ISolution solution)
        {
            Post["/reloadsolution"] = x =>
                {
                    solution.Reload();
                    return Response.AsJson(true);
                };
        }
    }
}
