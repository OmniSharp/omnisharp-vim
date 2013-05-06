using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.Rename
{
    public class RenameModule : NancyModule
    {
        public RenameModule(RenameHandler renameHandler)
        {
            Post["/rename"] = x =>
            {
                var req = this.Bind<RenameRequest>();
                var usages = renameHandler.Rename(req);
                return Response.AsJson(usages);
            };
        }
    }
}
