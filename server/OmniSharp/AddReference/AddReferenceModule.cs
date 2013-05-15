using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.AddReference
{
    public class AddReferenceModule : NancyModule
    {
        public AddReferenceModule(AddReferenceHandler handler)
        {
            Post["/addreference"] = x =>
                {
                    var req = this.Bind<AddReferenceRequest>();
                    var res = handler.AddReference(req);
                    return res;
                };
        }
    }
}