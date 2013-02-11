using Nancy;
using Nancy.ModelBinding;
using OmniSharp.AutoComplete;

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
