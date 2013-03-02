using System.Linq;
using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.AutoComplete
{
    public class AutoCompleteModule : NancyModule
    {
        public AutoCompleteModule(AutoCompleteHandler autoCompleteHandler)
        {
            Post["/autocomplete"] = x =>
                {
                    var req = this.Bind<AutoCompleteRequest>();
                    var completions = autoCompleteHandler.CreateProvider(req);
                    return Response.AsJson(completions.Select(c => new AutoCompleteResponse(c)));
                };
        }

        
    }
}
