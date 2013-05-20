using System;
using System.IO;

namespace OmniSharp.Solution
{
    public static class StringExtensions
    {
        /// <summary>
        /// Changes a path's directory separator from Windows-style to the native
        /// separator if necessary and expands it to the full path name.
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>
        public static string FixPath(this string path)
        {
            if (Path.DirectorySeparatorChar != '\\')
                path = path.Replace('\\', Path.DirectorySeparatorChar);
            else
                // TODO: fix hack - vim sends drive letter as uppercase. usually lower case in project files
                return path.Replace(@"C:\", @"c:\").Replace(@"D:\", @"d:\");
            return Path.GetFullPath(path);
        }

        /// <summary>
        /// Returns the relative path of a file to another file
        /// </summary>
        /// <param name="path">Base path to create relative path</param>
        /// <param name="pathToMakeRelative">Path of file to make relative against path</param>
        /// <returns></returns>
        public static string GetRelativePath(this string path, string pathToMakeRelative)
        {
            return new Uri(path).MakeRelativeUri(new Uri(pathToMakeRelative)).ToString().Replace("/", @"\");
        }
    }
}
