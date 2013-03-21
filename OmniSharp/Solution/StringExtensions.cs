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
    }
}
