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
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.TypeSystem;
using ICSharpCode.NRefactory.Utils;

namespace OmniSharp.Solution
{
    public interface IProject
    {
        IProjectContent ProjectContent { get; set; }
        string Title { get; set; }
        List<CSharpFile> Files { get; }
        CSharpParser CreateParser();
    }

    public class CSharpProject : IProject
    {
        public static readonly string[] AssemblySearchPaths = {
			@"C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.0",
			@"C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\v3.5",
			@"C:\Windows\Microsoft.NET\Framework\v2.0.50727",
			@"C:\Program Files (x86)\GtkSharp\2.12\lib\gtk-sharp-2.0",
			@"C:\Program Files (x86)\GtkSharp\2.12\lib\Mono.Posix",
			@"C:\work\SD\src\Tools\NUnit"
		};

        public readonly ISolution Solution;
        public string Title { get; set; }
        public readonly string AssemblyName;
        public readonly string FileName;

        readonly List<CSharpFile> _files = new List<CSharpFile>();

        public readonly bool AllowUnsafeBlocks;
        public readonly bool CheckForOverflowUnderflow;
        public readonly string[] PreprocessorDefines;

        ////public ICompilation Compilation
        //{
        //    get
        //    {
        //        return Solution.SolutionSnapshot.GetCompilation(ProjectContent);
        //    }
        //}

        public CSharpProject(ISolution solution, string title, string fileName)
        {
            this.Solution = solution;
            this.Title = title;
            this.FileName = fileName;

            var p = new Microsoft.Build.Evaluation.Project(fileName);
            this.AssemblyName = p.GetPropertyValue("AssemblyName");
            this.AllowUnsafeBlocks = GetBoolProperty(p, "AllowUnsafeBlocks") ?? false;
            this.CheckForOverflowUnderflow = GetBoolProperty(p, "CheckForOverflowUnderflow") ?? false;
            this.PreprocessorDefines = p.GetPropertyValue("DefineConstants").Split(new char[] { ';' }, StringSplitOptions.RemoveEmptyEntries);
            foreach (var item in p.GetItems("Compile"))
            {
                string path = Path.Combine(p.DirectoryPath, item.EvaluatedInclude);
                if (File.Exists(path))
                    _files.Add(new CSharpFile(this, path));
            }
            List<IAssemblyReference> references = new List<IAssemblyReference>();
            string mscorlib = FindAssembly(AssemblySearchPaths, "mscorlib");
            if (mscorlib != null)
            {
                references.Add(LoadAssembly(mscorlib));
            }
            else
            {
                Console.WriteLine("Could not find mscorlib");
            }
            bool hasSystemCore = false;
            foreach (var item in p.GetItems("Reference"))
            {
                string assemblyFileName = null;
                if (item.HasMetadata("HintPath"))
                {
                    assemblyFileName = Path.Combine(p.DirectoryPath, item.GetMetadataValue("HintPath"));
                    if (!File.Exists(assemblyFileName))
                        assemblyFileName = null;
                }
                if (assemblyFileName == null)
                {
                    assemblyFileName = FindAssembly(AssemblySearchPaths, item.EvaluatedInclude);
                }
                if (assemblyFileName != null)
                {
                    if (Path.GetFileName(assemblyFileName).Equals("System.Core.dll", StringComparison.OrdinalIgnoreCase))
                        hasSystemCore = true;
                    Console.WriteLine("Loading assembly " + item.EvaluatedInclude);
                    try
                    {
                        references.Add(LoadAssembly(assemblyFileName));
                    }
                    catch (Exception e)
                    {
                        Console.WriteLine(e);
                    }

                }
                else
                {
                    Console.WriteLine("Could not find referenced assembly " + item.EvaluatedInclude);
                }
            }
            if (!hasSystemCore && FindAssembly(AssemblySearchPaths, "System.Core") != null)
                references.Add(LoadAssembly(FindAssembly(AssemblySearchPaths, "System.Core")));
            foreach (var item in p.GetItems("ProjectReference"))
            {
                references.Add(new ProjectReference(solution, item.GetMetadataValue("Name")));
            }
            this.ProjectContent = new CSharpProjectContent()
                .SetAssemblyName(this.AssemblyName)
                .AddAssemblyReferences(references)
                .AddOrUpdateFiles(_files.Select(f => f.ParsedFile));
        }

        public IProjectContent ProjectContent { get; set; }

        public List<CSharpFile> Files
        {
            get { return _files; }
        }

        string FindAssembly(IEnumerable<string> assemblySearchPaths, string evaluatedInclude)
        {
            if (evaluatedInclude.IndexOf(',') >= 0)
                evaluatedInclude = evaluatedInclude.Substring(0, evaluatedInclude.IndexOf(','));
            foreach (string searchPath in assemblySearchPaths)
            {
                string assemblyFile = Path.Combine(searchPath, evaluatedInclude + ".dll");
                if (File.Exists(assemblyFile))
                    return assemblyFile;
            }
            return null;
        }

        static bool? GetBoolProperty(Microsoft.Build.Evaluation.Project p, string propertyName)
        {
			int i;
            string val = p.GetPropertyValue(propertyName);
            if (val.Equals("true", StringComparison.OrdinalIgnoreCase))
                return true;
            if (val.Equals("false", StringComparison.OrdinalIgnoreCase))
                return false;
			i.ToString();
            return null;
        }
            public void Dummy()
			
			
			{
				int i;
				i.ToString();
			}
        public CSharpParser CreateParser()
        {
            var settings = new CompilerSettings();
            settings.AllowUnsafeBlocks = AllowUnsafeBlocks;
            foreach (string define in PreprocessorDefines)
                settings.ConditionalSymbols.Add(define);
            return new CSharpParser(settings);
        }

        public override string ToString()
        {
            return string.Format("[CSharpProject AssemblyName={0}]", AssemblyName);
        }

        public CSharpFile GetFile(string fileName)
        {
            return _files.Single(f => f.FileName == fileName);
        }

        static ConcurrentDictionary<string, IUnresolvedAssembly> assemblyDict = new ConcurrentDictionary<string, IUnresolvedAssembly>(Platform.FileNameComparer);

        public static IUnresolvedAssembly LoadAssembly(string assemblyFileName)
        {
            return assemblyDict.GetOrAdd(assemblyFileName, file => new CecilLoader().LoadAssemblyFile(file));
        }
    }
}
