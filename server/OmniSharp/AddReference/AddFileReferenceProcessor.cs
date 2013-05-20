using System.IO;
using System.Linq;
using System.Xml.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddFileReferenceProcessor : ReferenceProcessorBase, IReferenceProcessor
    {
        public AddReferenceResponse AddReference(IProject project, string reference)
        {
            var response = new AddReferenceResponse();

            var projectXml = project.AsXml();

            var compilationNodes = projectXml.Element(MsBuildNameSpace + "Project")
                                             .Elements(MsBuildNameSpace + "ItemGroup")
                                             .Elements(MsBuildNameSpace + "Reference").ToList();

            var relativeReferencePath = project.FileName.GetRelativePath(reference);

            var referenceName = reference.Substring(reference.LastIndexOf(Path.DirectorySeparatorChar) + 1).Replace(".dll", "");

            var referenceAlreadyAdded = compilationNodes.Any(n => n.Attribute("Include").Value.Equals(referenceName));

            var fileReferenceNode = CreateReferenceNode(relativeReferencePath, referenceName);

            if (!referenceAlreadyAdded)
            {
                if (compilationNodes.Count > 0)
                {
                    compilationNodes.First().Parent.Add(fileReferenceNode);
                }
                else
                {
                    var projectItemGroup = new XElement(MsBuildNameSpace + "ItemGroup");
                    projectItemGroup.Add(fileReferenceNode);
                    projectXml.Element(MsBuildNameSpace + "Project").Add(projectItemGroup);
                }

                project.AddReference(reference.FixPath());
                project.Save(projectXml);

                response.Message = string.Format("Reference to {0} added successfully", referenceName);
            }
            else
            {
                response.Message = "Reference already added";
            }

            return response;

        }

        XElement CreateReferenceNode(string relativeReferencePath, string referenceName)
        {
            var projectReferenceNode =
                new XElement(MsBuildNameSpace + "Reference",
                    new XAttribute("Include", referenceName));

            projectReferenceNode.Add(
                new XElement(MsBuildNameSpace + "HintPath",
                    new XText(relativeReferencePath)));

            return projectReferenceNode;
        }
    }
}
