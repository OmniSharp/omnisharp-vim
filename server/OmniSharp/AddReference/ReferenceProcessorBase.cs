using System.Xml.Linq;

namespace OmniSharp.AddReference
{
    public abstract class ReferenceProcessorBase
    {
        protected readonly XNamespace MsBuildNameSpace = "http://schemas.microsoft.com/developer/msbuild/2003";
    }
}