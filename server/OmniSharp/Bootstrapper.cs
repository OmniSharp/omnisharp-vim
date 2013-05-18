using Nancy.Json;
using Nancy.TinyIoc;
using Nancy.Bootstrapper;
using OmniSharp.AddReference;
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

        protected override void ApplicationStartup(TinyIoCContainer container, IPipelines pipelines)
        {
            pipelines.OnError.AddItemToEndOfPipeline((ctx, ex) =>
                {
                    System.Console.WriteLine(ex);
                    return null;
                });
        }

        protected override void ConfigureApplicationContainer(TinyIoCContainer container)
        {
            base.ConfigureApplicationContainer(container);
            container.Register(_solution);
			container.RegisterMultiple<IReferenceProcessor>(new []{typeof(AddProjectReferenceProcessor)});			
        }
    }
}
