using System;
using System.IO;
using System.Linq;
using System.Xml.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public class AddFileReferenceProcessor : IReferenceProcessor
    {
        private readonly ISolution _solution;
        private readonly XNamespace _msBuildNameSpace = "http://schemas.microsoft.com/developer/msbuild/2003";

        public AddFileReferenceProcessor(ISolution solution)
        {
            _solution = solution;
        }

        public AddReferenceResponse AddReference(IProject project, string reference)
        {
            var response = new AddReferenceResponse();

            var projectXml = project.AsXml();

            var compilationNodes = projectXml.Element(_msBuildNameSpace + "Project")
                                             .Elements(_msBuildNameSpace + "ItemGroup")
                                             .Elements(_msBuildNameSpace + "Reference").ToList();

            var relativeReferencePath = project.FileName.GetRelativePath(reference);

            var referenceName = reference.Substring(reference.LastIndexOf(Path.DirectorySeparatorChar) + 1).Replace(".dll", "");

            var projectReferenceNode = CreateReferenceNode(relativeReferencePath, referenceName);

            compilationNodes.First().Parent.Add(projectReferenceNode);

            project.Save(projectXml);

            return response;

        }

        XElement CreateReferenceNode(string relativeReferencePath, string referenceName)
        {
            var projectReferenceNode =
                new XElement(_msBuildNameSpace + "Reference",
                    new XAttribute("Include", referenceName));

            projectReferenceNode.Add(
                new XElement(_msBuildNameSpace + "HintPath",
                    new XText(relativeReferencePath)));

            return projectReferenceNode;
        }
    }
}
