using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.AddToProject
{
    public class AddToProjectModule : NancyModule
    {
        public AddToProjectModule(AddToProjectHandler handler)
        {
            Post["/addtoproject"] = x =>
                {
                    var req = this.Bind<AddToProjectRequest>();
                    handler.AddToProject(req);
                    return Response.AsJson(true);
                };
        }
    }
}