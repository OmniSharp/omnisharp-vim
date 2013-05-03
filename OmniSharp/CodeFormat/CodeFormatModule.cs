using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.CodeFormat
{
    public class CodeFormatModule : NancyModule
    {
        public CodeFormatModule(CodeFormatHandler codeFormatHandler)
        {
            Post["/codeformat"] = x =>
                {
                    var request = this.Bind<Common.Request>();
                    return Response.AsJson(codeFormatHandler.Format(request));
                };
        }
    }
}
