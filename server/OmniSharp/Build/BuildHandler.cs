using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Text.RegularExpressions;
using OmniSharp.Common;
using OmniSharp.Solution;

namespace OmniSharp.Build
{
    public class BuildHandler
    {
        private readonly ISolution _solution;
        private readonly BuildResponse _response;
        private readonly List<QuickFix> _quickFixes;

        public BuildHandler(ISolution solution)
        {
            _solution = solution;
            _response = new BuildResponse();
            _quickFixes = new List<QuickFix>();
        }

		private static bool IsUnix
		{
			get
			{
				var p = (int)Environment.OSVersion.Platform;
				return (p == 4) || (p == 6) || (p == 128);
			}
		}

        public BuildResponse Build()
        {
			var build = IsUnix
						? "xbuild" 
						: @"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Msbuild.exe";

            var startInfo = new ProcessStartInfo
                {
                    FileName = build,
                    Arguments = IsUnix ? "" : "/m " + "/nologo /property:GenerateFullPaths=true \"" + _solution.FileName + "\"",
                    RedirectStandardOutput = true,
                    RedirectStandardError = true,
                    RedirectStandardInput = true,
                    UseShellExecute = false,
                    CreateNoWindow = true
                };

            var process = new Process
                {
                    StartInfo = startInfo,
                    EnableRaisingEvents = true
                };

            process.ErrorDataReceived += ErrorDataReceived;
            process.OutputDataReceived += OutputDataReceived;
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            process.WaitForExit();
            _response.QuickFixes = _quickFixes;

            return _response;
        }

        void OutputDataReceived(object sender, DataReceivedEventArgs e)
        {
            Console.WriteLine(e.Data);
            if (e.Data == null)
                return;

            if (e.Data == "Build succeeded.")
                _response.Success = true;
            if (e.Data.Contains("error CS"))
            {
                var matches = Regex.Matches(e.Data, @"\s+(.*cs)\((\d+),(\d+)\).*error CS\d+: (.*) \[", RegexOptions.Compiled);
                if (!Regex.IsMatch(matches[0].Groups[1].Value, @"\d+>"))
                {
                    var quickFix = new QuickFix
                    {
                        FileName = matches[0].Groups[1].Value,
                        Line = int.Parse(matches[0].Groups[2].Value),
                        Column = int.Parse(matches[0].Groups[3].Value),
                        Text = matches[0].Groups[4].Value.Replace("'", "''")
                    };

                    _quickFixes.Add(quickFix);    
                }
            }
        }

        void ErrorDataReceived(object sender, DataReceivedEventArgs e)
        {
            Console.WriteLine(e.Data);
        }
    }
}
