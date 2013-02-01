using System.Linq;
using Nancy.Bootstrapper;
using Nancy.Json;
using Nancy.TinyIoc;
using OmniSharp.AutoComplete;

namespace OmniSharp
{
    public class Bootstrapper : Nancy.DefaultNancyBootstrapper
    {
        private readonly CompletionProvider _completionProvider;

        public Bootstrapper(CompletionProvider completionProvider)
        {
            _completionProvider = completionProvider;
            JsonSettings.MaxJsonLength = 500000;
        }

        protected override void ConfigureApplicationContainer(TinyIoCContainer container)
        {
            base.ConfigureApplicationContainer(container);
            container.Register(_completionProvider);
        }

        
    }
}
