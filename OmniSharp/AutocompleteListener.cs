using System.Linq;
using Nancy;
using Nancy.ModelBinding;
using OmniSharp.AutoComplete;

namespace OmniSharp
{
    public class AutocompleteListener : NancyModule
    {
        public AutocompleteListener(CompletionProvider completionProvider)
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
