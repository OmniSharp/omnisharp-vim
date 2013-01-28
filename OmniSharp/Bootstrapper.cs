using Nancy.TinyIoc;

namespace OmniSharp
{
    public class Bootstrapper : Nancy.DefaultNancyBootstrapper
    {
        private readonly CompletionProvider _completionProvider;

        public Bootstrapper(CompletionProvider completionProvider)
        {
            _completionProvider = completionProvider;
        }

        protected override void ConfigureApplicationContainer(TinyIoCContainer container)
        {
            base.ConfigureApplicationContainer(container);
            container.Register(_completionProvider);
        }
    }
}
