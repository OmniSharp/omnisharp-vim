// Copyright (c) AlphaSierraPapa for the SharpDevelop Team
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy of this
// software and associated documentation files (the "Software"), to deal in the Software
// without restriction, including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons
// to whom the Software is furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in all copies or
// substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
// INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
// PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
// FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
// OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Xml.Linq;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.TypeSystem;
using ICSharpCode.NRefactory.Utils;

namespace OmniSharp.Solution
{
    public interface IProject
    {
        IProjectContent ProjectContent { get; set; }
        string Title { get; }
        string FileName { get; }
        List<CSharpFile> Files { get; }
        List<IAssemblyReference> References { get; set; }
        CSharpFile GetFile(string fileName);
        CSharpParser CreateParser();
        XDocument AsXml();
        void Save(XDocument project);
    }

    public class CSharpProject : IProject
    {
        public static readonly string[] AssemblySearchPaths = {
            //Windows Paths
            @"C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.0",
            @"C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\v3.5",
            @"C:\Windows\Microsoft.NET\Framework\v2.0.50727",

            //Unix Paths
            @"/usr/local/lib/mono/4.0",
            @"/usr/local/lib/mono/3.5",
            @"/usr/local/lib/mono/2.0",
            @"/usr/lib/mono/4.0",
            @"/usr/lib/mono/3.5",
            @"/usr/lib/mono/2.0",

            //OS X Paths
            @"/Library/Frameworks/Mono.Framework/Libraries/mono/4.5",
            @"/Library/Frameworks/Mono.Framework/Libraries/mono/4.0",
            @"/Library/Frameworks/Mono.Framework/Libraries/mono/3.5",
            @"/Library/Frameworks/Mono.Framework/Libraries/mono/2.0",
        };

        public readonly ISolution Solution;
        public readonly string AssemblyName;
        public string FileName { get; private set; }

        public string Title { get; private set; }
        public IProjectContent ProjectContent { get; set; }
        public List<CSharpFile> Files { get; private set; }

        private CompilerSettings _compilerSettings;

        public CSharpProject(ISolution solution, string title, string fileName)
        {
            Solution = solution;
            Title = title;
            FileName = fileName;
            Files = new List<CSharpFile>();

            var p = new Microsoft.Build.Evaluation.Project(FileName);
            AssemblyName = p.GetPropertyValue("AssemblyName");

            _compilerSettings = new CompilerSettings()
                {
                    AllowUnsafeBlocks = GetBoolProperty(p, "AllowUnsafeBlocks") ?? false,
                    CheckForOverflow = GetBoolProperty(p, "CheckForOverflowUnderflow") ?? false,
                };
            string[] defines = p.GetPropertyValue("DefineConstants").Split(new char[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (string define in defines)
                _compilerSettings.ConditionalSymbols.Add(define);

            foreach (var item in p.GetItems("Compile"))
            {
                try
                {
                    string path = Path.Combine(p.DirectoryPath, item.EvaluatedInclude).FixPath();
                    if (File.Exists(path))
                        Files.Add(new CSharpFile(this, path));
                }
                catch (NullReferenceException)
                {
                }
            }

            References = new List<IAssemblyReference>();
            string mscorlib = FindAssembly(AssemblySearchPaths, "mscorlib");
            if (mscorlib != null)
                References.Add(LoadAssembly(mscorlib));
            else
                Console.WriteLine("Could not find mscorlib");

            bool hasSystemCore = false;
            foreach (var item in p.GetItems("Reference"))
            {

                string assemblyFileName = null;
                if (item.HasMetadata("HintPath"))
                {
                    assemblyFileName = Path.Combine(p.DirectoryPath, item.GetMetadataValue("HintPath")).FixPath();
                    if (!File.Exists(assemblyFileName))
                        assemblyFileName = null;
                }
                //If there isn't a path hint or it doesn't exist, try searching
                if (assemblyFileName == null)
                    assemblyFileName = FindAssembly(AssemblySearchPaths, item.EvaluatedInclude);

                if (assemblyFileName != null)
                {
                    if (Path.GetFileName(assemblyFileName).Equals("System.Core.dll", StringComparison.OrdinalIgnoreCase))
                        hasSystemCore = true;
                    Console.WriteLine("Loading assembly " + item.EvaluatedInclude);
                    try
                    {
                        References.Add(LoadAssembly(assemblyFileName));
                    }
                    catch (Exception e)
                    {
                        Console.WriteLine(e);
                    }

                }
                else
                    Console.WriteLine("Could not find referenced assembly " + item.EvaluatedInclude);
            }
            if (!hasSystemCore && FindAssembly(AssemblySearchPaths, "System.Core") != null)
                References.Add(LoadAssembly(FindAssembly(AssemblySearchPaths, "System.Core")));
            foreach (var item in p.GetItems("ProjectReference"))
                References.Add(new ProjectReference(Solution, item.GetMetadataValue("Name")));

            this.ProjectContent = new CSharpProjectContent()
                .SetAssemblyName(this.AssemblyName)
                .AddAssemblyReferences(References)
                .AddOrUpdateFiles(Files.Select(f => f.ParsedFile));
            
        }

        public List<IAssemblyReference> References { get; set; }

        public CSharpFile GetFile(string fileName)
        {
            return Files.Single(f => f.FileName.Equals(fileName, StringComparison.InvariantCultureIgnoreCase));
        }

        public CSharpParser CreateParser()
        {
            return new CSharpParser(_compilerSettings);
        }

        public XDocument AsXml()
        {
            return XDocument.Load(FileName);
        }

        public void Save(XDocument project)
        {
            project.Save(FileName);
        }

        public override string ToString()
        {
            return string.Format("[CSharpProject AssemblyName={0}]", AssemblyName);
        }

        #region Static Members
        static ConcurrentDictionary<string, IUnresolvedAssembly> assemblyDict = new ConcurrentDictionary<string, IUnresolvedAssembly>(Platform.FileNameComparer);

        public static IUnresolvedAssembly LoadAssembly(string assemblyFileName)
        {
            return assemblyDict.GetOrAdd(assemblyFileName, file => new CecilLoader().LoadAssemblyFile(file));
        }

        public static string FindAssembly(IEnumerable<string> assemblySearchPaths, string evaluatedInclude)
        {
            if (evaluatedInclude.IndexOf(',') >= 0)
                evaluatedInclude = evaluatedInclude.Substring(0, evaluatedInclude.IndexOf(','));
            foreach (string searchPath in assemblySearchPaths)
            {
                string assemblyFile = Path.Combine(searchPath, evaluatedInclude + ".dll").FixPath();
                if (File.Exists(assemblyFile))
                    return assemblyFile;
            }
            return null;
        }


        static bool? GetBoolProperty(Microsoft.Build.Evaluation.Project p, string propertyName)
        {
            string val = p.GetPropertyValue(propertyName);
            if (val.Equals("true", StringComparison.OrdinalIgnoreCase))
                return true;
            if (val.Equals("false", StringComparison.OrdinalIgnoreCase))
                return false;
            return null;
        }
        #endregion
    }
}
