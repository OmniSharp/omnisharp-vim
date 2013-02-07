using Nancy.Json;
using Nancy.TinyIoc;
using OmniSharp.Solution;

namespace OmniSharp
{
    public class Bootstrapper : Nancy.DefaultNancyBootstrapper
    {
        private readonly ISolution _solution;

        public Bootstrapper(ISolution solution)
        {
            _solution = solution;
            JsonSettings.MaxJsonLength = int.MaxValue;
        }

        protected override void ConfigureApplicationContainer(TinyIoCContainer container)
        {
            base.ConfigureApplicationContainer(container);
            container.Register(_solution);
        }
    }
}
