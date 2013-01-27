using System;
using NDesk.Options;
using Nancy.Diagnostics;
using OmniSharp.Solution;

namespace OmniSharp
{
    internal static class Program
    {
        private static void Main(string[] args)
        {
            bool showHelp = false;
            string solutionPath = null;

            int port = 2000;
            var p = new OptionSet
                        {
                            {
                                "s|solution=", "The path to the solution file",
                                v => solutionPath = v
                            },
                            {
                                "p|port=", "Port number to listen on",
                                (int v) => port = v
                            },
                            {
                                "h|help", "show this message and exit",
                                v => showHelp = v != null
                            },
                        };

            try
            {
                p.Parse(args);
            }
            catch (OptionException e)
            {
                Console.WriteLine(e.Message);
                Console.WriteLine("Try 'omnisharp --help' for more information.");
                return;
            }

            showHelp |= solutionPath == null;

            if (showHelp)
            {
                ShowHelp(p);
                return;
            }

            var _logger = new Logger();
            var solution = new CSharpSolution(solutionPath);

            var completionProvider = new CompletionProvider(solution, _logger);
            var nancyHost = new Nancy.Hosting.Self.NancyHost(new Bootstrapper(completionProvider), new Uri("http://localhost:" + port));
            
            
            nancyHost.Start();
 
            Console.ReadLine();
            nancyHost.Stop();
            //var listener = new Listener(solutionPath, port);
            //listener.Start();
        }

        static void ShowHelp(OptionSet p)
        {
            Console.WriteLine("Usage: greet [OPTIONS]+ message");
            Console.WriteLine("Greet a list of individuals with an optional message.");
            Console.WriteLine("If no message is specified, a generic greeting is used.");
            Console.WriteLine();
            Console.WriteLine("Options:");
            p.WriteOptionDescriptions(Console.Out);
        }
    }
}
