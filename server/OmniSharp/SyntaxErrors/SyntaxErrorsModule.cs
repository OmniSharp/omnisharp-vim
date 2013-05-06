using Nancy;
using Nancy.ModelBinding;
using Request = OmniSharp.Common.Request;

namespace OmniSharp.SyntaxErrors
{
    public class SyntaxErrorsModule : NancyModule
    {
        public SyntaxErrorsModule(SyntaxErrorsHandler handler)
        {
            Post["/syntaxerrors"] = x =>
                {
                    var req = this.Bind<Request>();
                    var res = handler.FindSyntaxErrors(req);
                    return Response.AsJson(res);
                };
        }
    }
}