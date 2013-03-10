using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.TypeLookup
{
    public class TypeLookupModule : NancyModule
    {
        public TypeLookupModule(TypeLookupHandler typeLookupHandler)
        {
            Post["/typelookup"] = x =>
                {
                    var req = this.Bind<TypeLookupRequest>();
                    var res = typeLookupHandler.GetTypeLookupResponse(req);
                    return Response.AsJson(res);
                };
        }
    }
}
