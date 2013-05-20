using System;
using System.Linq;
using System.Xml.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddProjectReferenceProcessor : ReferenceProcessorBase, IReferenceProcessor
    {
        private readonly ISolution _solution;
        
        public AddProjectReferenceProcessor(ISolution solution)
        {
            _solution = solution;
        }

        public AddReferenceResponse AddReference(IProject project, string reference)
        {
            var response = new AddReferenceResponse();

            var projectToReference = _solution.Projects.First(p => p.FileName.Contains(reference));

            var projectXml = project.AsXml();

            var compilationNodes = projectXml.Element(MsBuildNameSpace + "Project")
                                             .Elements(MsBuildNameSpace + "ItemGroup")
                                             .Elements(MsBuildNameSpace + "ProjectReference").ToList();
            
            var relativeProjectPath = project.FileName.GetRelativePath(projectToReference.FileName);

            var projectReferenceNode = CreateProjectReferenceNode(relativeProjectPath, projectToReference);

            var projectAlreadyAdded = compilationNodes.Any(n => n.Attribute("Include").Value.Equals(relativeProjectPath));

            if (IsCircularReference(project, projectToReference))
            {
                response.Message = "Reference will create circular dependency";
                return response;
            }

            if (!projectAlreadyAdded)
            {
                var projectContainsProjectReferences = compilationNodes.Count > 0;

                if (projectContainsProjectReferences)
                {
                    compilationNodes.First().Parent.Add(projectReferenceNode);
                }
                else
                {
                    var projectItemGroup = new XElement(MsBuildNameSpace + "ItemGroup");
                    projectItemGroup.Add(projectReferenceNode);
                    projectXml.Element(MsBuildNameSpace + "Project").Add(projectItemGroup);
                }

                project.AddReference(new ProjectReference(_solution, projectToReference.Title));
                project.Save(projectXml);
                response.Message = string.Format("Reference to {0} added successfully", projectToReference.Title);
            }
            else
            {
                response.Message = "Reference already added";
            }

            return response;
        }

        XElement CreateProjectReferenceNode(string relativeProjectPath, IProject projectToReference)
        {
            var projectReferenceNode =
                new XElement(MsBuildNameSpace + "ProjectReference", 
                    new XAttribute("Include", relativeProjectPath));

            projectReferenceNode.Add(
                new XElement(MsBuildNameSpace + "Project", 
                    new XText(string.Concat("{",projectToReference.ProjectId.ToString().ToUpperInvariant(), "}"))));

            projectReferenceNode.Add(new XElement(MsBuildNameSpace + "Name", new XText(projectToReference.Title)));

            return projectReferenceNode;
        }

        bool IsCircularReference(IProject project, IProject projectToReference)
        {
            return projectToReference.References.Cast<ProjectReference>().Any(r => r.ProjectTitle == project.Title);
        }
    }
}