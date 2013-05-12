using System;
using System.Linq;
using System.Xml.Linq;
using OmniSharp.Solution;

namespace OmniSharp.AddToProject
{
    public class AddToProjectHandler
    {
        private readonly ISolution _solution;
        private readonly XNamespace _msBuildNameSpace = "http://schemas.microsoft.com/developer/msbuild/2003";
        private readonly string _osSpecificFileSeparator;

        public AddToProjectHandler(ISolution solution)
        {
            _solution = solution;
            _osSpecificFileSeparator = solution.FileName.Contains(@"\") ? @"\" : "/";
        }

        public void AddToProject(AddToProjectRequest request)
        {
            if (request.FileName == null || !request.FileName.EndsWith(".cs"))
            {
                return;
            }

            var relativeProject = _solution.ProjectContainingFile(request.FileName);

            if (relativeProject == null || relativeProject is OrphanProject)
            {
                throw new ProjectNotFoundException(string.Format("Unable to find project relative to file {0}", request.FileName));
            }

            var project = relativeProject.AsXml();

            var relativeFileName = request.FileName.Replace(relativeProject.FileName.Substring(0, relativeProject.FileName.LastIndexOf(_osSpecificFileSeparator) + 1), "")
                .Replace(_osSpecificFileSeparator, @"\");

            var compilationNodes = project.Element(_msBuildNameSpace + "Project")
                                          .Elements(_msBuildNameSpace + "ItemGroup")
                                          .Elements(_msBuildNameSpace + "Compile").ToList();

            var fileAlreadyInProject = compilationNodes.Any(n => n.Attribute("Include").Value.Equals(relativeFileName, StringComparison.InvariantCultureIgnoreCase));

            if (!fileAlreadyInProject)
            {
                var compilationNodeParent = compilationNodes.First().Parent;

                var newFileElement = new XElement(_msBuildNameSpace + "Compile", new XAttribute("Include", relativeFileName));

                compilationNodeParent.Add(newFileElement);

                relativeProject.Save(project);
            }
        }
    }
}