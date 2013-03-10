using System.IO;

namespace OmniSharp.Solution
{
    public static class StringExtensions
    {
        /// <summary>
        /// Changes a path's directory seperator from Windows-style to the native
        /// seperator if necessary and expands it to the full path name.
        /// </summary>
        /// <param name="path"></param>
        /// <returns></returns>
        public static string FixPath(this string path)
        {
            if (Path.DirectorySeparatorChar != '\\')
                path = path.Replace('\\', Path.DirectorySeparatorChar);
            return Path.GetFullPath(path);
        }
    }
}
