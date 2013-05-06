using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.FindUsages
{
    public class FindUsagesModule : NancyModule
    {
        public FindUsagesModule(FindUsagesHandler findUsagesHandler)
        {
            Post["/findusages"] = x =>
            {
                var req = this.Bind<FindUsagesRequest>();
                var usages = findUsagesHandler.FindUsages(req);
                return Response.AsJson(usages);
            };    
        }
    }
}
