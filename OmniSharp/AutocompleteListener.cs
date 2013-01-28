using System;
using System.Text;
using Nancy.ModelBinding;

namespace OmniSharp
{
    public class AutocompleteListener : Nancy.NancyModule
    {
        public AutocompleteListener(CompletionProvider completionProvider)
        {
            Post["/autocomplete"] = x =>
                {
                    var req = this.Bind<AutocompleteRequest>();
                    var completions = completionProvider.CreateProvider(req);
                    var sb = new StringBuilder();
                    foreach (var completion in completions)
                    {
                        sb.AppendFormat("add(res, {{'word':'{0}', 'abbr':'{1}', 'info':\"{2}\", 'icase':1, 'dup':1}})\n",
                                        completion.CompletionText, completion.DisplayText,
                                        completion.Description.Replace(Environment.NewLine, "\\n").Replace("\"", "''"));

                    }

                    var res = sb.ToString();
                    Console.WriteLine(res);
                    return res;
                };
        }
    }
}
