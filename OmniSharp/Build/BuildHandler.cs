using System;
using System.Diagnostics;
using System.Net;
using System.Text;
using OmniSharp.Solution;

namespace OmniSharp.Build
{
    public class BuildHandler
    {
        private readonly ISolution _solution;
        private StringBuilder _output = new StringBuilder();

        public BuildHandler(ISolution solution)
        {
            _solution = solution;
        }

        public string Build()
        {
            var startInfo = new ProcessStartInfo
                {
                    FileName = @"C:\Windows\Microsoft.NET\Framework64\v4.0.30319\Msbuild.exe",
                    Arguments = "/m /nologo " + _solution.FileName,
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
            return _output.ToString();
        }

        void OutputDataReceived(object sender, DataReceivedEventArgs e)
        {
            Console.WriteLine(e.Data);
            _output.Append(e.Data);
        }

        void ErrorDataReceived(object sender, DataReceivedEventArgs e)
        {
            Console.WriteLine(e.Data);
        }
    }
}