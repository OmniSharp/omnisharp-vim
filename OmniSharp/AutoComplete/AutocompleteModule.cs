using System.Linq;
using Nancy;
using Nancy.ModelBinding;

namespace OmniSharp.AutoComplete
{
    public class AutocompleteModule : NancyModule
    {
        public AutocompleteModule(CompletionProvider completionProvider)
        {
            Post["/autocomplete"] = x =>
                {
                    var req = this.Bind<AutocompleteRequest>();
                    var completions = completionProvider.CreateProvider(req);
                    return Response.AsJson(completions.Select(c => new CompletionDataDto(c)));
                };
        }

        
    }
}
