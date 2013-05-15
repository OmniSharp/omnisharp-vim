using System.Linq;
using System.Xml.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddReferenceHandler
    {
        private readonly ISolution _solution;
        private readonly XNamespace _msBuildNameSpace = "http://schemas.microsoft.com/developer/msbuild/2003";

        public AddReferenceHandler(ISolution solution)
        {
            _solution = solution;
        }

        public AddReferenceResponse AddReference(AddReferenceRequest request)
        {
            var project = _solution.Projects.First(p => p.FileName == request.CurrentProject);

            var projectXml = project.AsXml();

            var compilationNodes = projectXml.Element(_msBuildNameSpace + "Project")
                                        .Elements(_msBuildNameSpace + "ItemGroup")
                                        .Elements(_msBuildNameSpace + "ProjectReference").ToList();
            
            var projectContainsProjectReferences = compilationNodes.Count > 0;

            var projectReferenceNode = new XElement(_msBuildNameSpace + "ProjectReference", new XAttribute("Include", request.Reference));

            if (!projectContainsProjectReferences)
            {
   
            }

            return null;
        }
    }
}