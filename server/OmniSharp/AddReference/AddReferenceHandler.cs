using System;
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
            var project = _solution.ProjectContainingFile(request.FileName);

            if (project != null)
            {
                AddProjectReference(request, project);
            }
            
            return null;
        }

        private void AddProjectReference(AddReferenceRequest request, IProject project)
        {
            var projectToReference = _solution.Projects.First(p => p.FileName.Contains(request.Reference));

            var projectXml = project.AsXml();

            var compilationNodes = projectXml.Element(_msBuildNameSpace + "Project")
                                        .Elements(_msBuildNameSpace + "ItemGroup")
                                        .Elements(_msBuildNameSpace + "ProjectReference").ToList();

            var projectContainsProjectReferences = compilationNodes.Count > 0;

            var relativeProjectPath = new Uri(project.FileName).MakeRelativeUri(new Uri(projectToReference.FileName)).ToString().Replace("/", @"\");

            var projectReferenceNode = new XElement(_msBuildNameSpace + "ProjectReference", new XAttribute("Include", relativeProjectPath));
            projectReferenceNode.Add(new XElement(_msBuildNameSpace + "Project", new XText(string.Concat("{", projectToReference.ProjectId.ToString().ToUpperInvariant(), "}"))));
            projectReferenceNode.Add(new XElement(_msBuildNameSpace + "Name", new XText(projectToReference.Title)));

            var projectAlreadyAdded = compilationNodes.Any(n => n.Attribute("Include").Value.Equals(relativeProjectPath));

            if (!projectAlreadyAdded)
            {
                if (projectContainsProjectReferences)
                {
                    compilationNodes.First().Parent.Add(projectReferenceNode);
                }
                else
                {
                    var projectItemGroup = new XElement(_msBuildNameSpace + "ItemGroup");
                    projectItemGroup.Add(projectReferenceNode);
                    projectXml.Element(_msBuildNameSpace + "Project").Add(projectItemGroup);
                }


                project.Save(projectXml);
            }
        }
    }
}