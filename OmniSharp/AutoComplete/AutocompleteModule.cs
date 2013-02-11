using System.Linq;
using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.AutoComplete
{
    public class AutocompleteModule : NancyModule
    {
        public AutocompleteModule(AutoCompleteHandler autoCompleteHandler)
        {
            Post["/autocomplete"] = x =>
                {
                    var req = this.Bind<AutocompleteRequest>();
                    var completions = autoCompleteHandler.CreateProvider(req);
                    return Response.AsJson(completions.Select(c => new AutoCompleteResponse(c)));
                };
        }

        
    }
}
