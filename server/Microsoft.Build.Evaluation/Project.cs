using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Xml.Linq;

namespace Microsoft.Build.Evaluation
{
    public class Project
    {

        public string DirectoryPath { get; private set; }

        private XDocument document;


        public Project(string fileName)
        {
            DirectoryPath = Path.GetDirectoryName(fileName);
            document = XDocument.Load(fileName);
        }

        public string GetPropertyValue(string name)
        {
            XElement element = document.Descendants(document.Root.Name.Namespace + "PropertyGroup").Descendants(document.Root.Name.Namespace + name).FirstOrDefault();
            return element == null ? string.Empty : element.Value;
        }

        public ICollection<ProjectItem> GetItems(string itemType)
        {
            IEnumerable<XElement> elements = document.Descendants(document.Root.Name.Namespace + "ItemGroup").Descendants(document.Root.Name.Namespace + itemType);
            return (from element in elements select new ProjectItem(element)).ToList();
        }
    }
}
