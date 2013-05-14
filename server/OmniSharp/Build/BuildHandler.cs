using System;
using System.Collections.Generic;
using System.Diagnostics;
using OmniSharp.Common;
using OmniSharp.Solution;

namespace OmniSharp.Build
{
    public class BuildHandler
    {
        private readonly ISolution _solution;
        private readonly BuildResponse _response;
        private readonly List<QuickFix> _quickFixes;
        private readonly BuildLogParser _logParser;

        public BuildHandler(ISolution solution)
        {
            _solution = solution;
            _response = new BuildResponse();
            _quickFixes = new List<QuickFix>();
            _logParser = new BuildLogParser();
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
            var quickfix = _logParser.Parse(e.Data);
            if(quickfix != null)
                _quickFixes.Add(quickfix);
        }

        void ErrorDataReceived(object sender, DataReceivedEventArgs e)
        {
            Console.WriteLine(e.Data);
        }
    }
}
