using System;
using System.Collections.Concurrent;
using System.IO;
using ICSharpCode.NRefactory.Documentation;

namespace OmniSharp.AutoComplete
{
    public static class XmlDocumentationProviderFactory
    {
        static readonly string referenceAssembliesPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), @"Reference Assemblies\Microsoft\\Framework");
        static readonly string frameworkPath = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows), @"Microsoft.NET\Framework");

        private static readonly ConcurrentDictionary<string, XmlDocumentationProvider> _providers =
            new ConcurrentDictionary<string, XmlDocumentationProvider>();
 

        public static XmlDocumentationProvider Get(string assemblyName)
        {
            if (_providers.ContainsKey(assemblyName))
                return _providers[assemblyName];

            var assemblyDllName = assemblyName + ".dll";

            //string assemblyFileName = entity.ParentAssembly.AssemblyName + ".dll";
            string fileName = XmlDocumentationProvider.LookupLocalizedXmlDoc(Path.Combine(referenceAssembliesPath, @".NETFramework\v4.0", assemblyDllName))
                        ?? XmlDocumentationProvider.LookupLocalizedXmlDoc(Path.Combine(frameworkPath, "v4.0.30319", assemblyDllName));
            //string fileName = XmlDocumentationProvider.LookupLocalizedXmlDoc(assemblyFileName);
            if (fileName != null)
            {
                var docProvider = new XmlDocumentationProvider(fileName);
                _providers.TryAdd(assemblyName, docProvider);
                return docProvider;
            }
            return null;
        }
    }
}

