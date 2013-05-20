using System.Collections.Generic;
using NUnit.Framework;
using OmniSharp.AddReference;
using OmniSharp.Solution;
using Should;

namespace OmniSharp.Tests.AddReference
{
    [TestFixture]
    public class AddToProjectProcessoryFactoryTests
    {
        IEnumerable<IReferenceProcessor> _processors;
        ISolution _solution;
        AddReferenceProcessorFactory _factory;

        [SetUp]
        public void SetUp()
        {
            _solution = new FakeSolution();
            var project = new FakeProject();
            _solution.Projects.Add(project);
            _processors = new List<IReferenceProcessor>
                              {
                                  new AddProjectReferenceProcessor(_solution),
                                  new AddFileReferenceProcessor(_solution)
                              };

            _factory = new AddReferenceProcessorFactory(_solution, _processors);
        }

        [Test]
        public void ShouldReturnAddProjectReferenceProcessorWhenReferencingProject()
        {
            var request = new AddReferenceRequest
                              {
                                  Reference = "fake"
                              };

            var processor = _factory.CreateProcessorFor(request);

            processor.ShouldBeType<AddProjectReferenceProcessor>();
        }

        [Test]
        public void ShouldReturnAddFileReferenceProcessorWhenReferencingFile()
        {
            var request = new AddReferenceRequest
                              {
                                  Reference = "test.dll"
                              };

            var processor = _factory.CreateProcessorFor(request);

            processor.ShouldBeType<AddFileReferenceProcessor>();
        }
    }
}
