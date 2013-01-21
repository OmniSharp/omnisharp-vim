using System;
using System.Linq;
using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Threading;
using OmniSharp.Solution;

namespace OmniSharp
{
    public class Listener
    {
        private readonly int _port;
        private readonly Logger _logger;
        private readonly CompletionProvider _completionProvider;
        private TcpListener _listener;

        public Listener(string solutionPath, int port)
        {
            _port = port;
            _logger = new Logger();
            var solution = new CSharpSolution(solutionPath);

            _completionProvider = new CompletionProvider(solution, _logger);
        }

        public void Start()
        {
            try
            {
                _listener = new TcpListener(IPAddress.Loopback, _port);
                _listener.Start();
                _logger.Debug("Server Running... Press ^C to Stop...");
                var thread = new Thread(StartListen);
                thread.Start();
            }
            catch (Exception e)
            {
                _logger.Error("An Exception Occurred while Listening :" + e);
            }
        }

        private void StartListen()
        {
            while (true)
            {
                //Accept a new connection
                Socket socket = _listener.AcceptSocket();

                _logger.Debug("Socket Type " + socket.SocketType);
                if (socket.Connected)
                {
                    _logger.Debug("\nClient Connected!!\n==================\n Client IP " + socket.RemoteEndPoint);
                    var bytes = new Byte[65536];
                    socket.Receive(bytes);
                    string buffer = Encoding.ASCII.GetString(bytes.TakeWhile(b => !b.Equals(0)).ToArray());
                    string[] lines = buffer.Split(new[] { "\r\n" }, StringSplitOptions.None);
                    int cursorPosition = int.Parse(lines[0]);
                    _logger.Debug(cursorPosition);
                    string partialWord = lines[1];
                    _logger.Debug(partialWord);
                    //cursorPosition += partialWord.Length;
                    string filename = lines[2].Trim();
                    string code = string.Join("\r\n", lines.Skip(3).ToArray());
                    _logger.Debug(code);
                    var sb = new StringBuilder();
                    var completions = _completionProvider.CreateProvider(filename, partialWord, code, cursorPosition, true);
                    foreach (var completion in completions)
                    {
                        sb.AppendFormat("add(res, {{'word':'{0}', 'abbr':'{1}', 'info':\"{2}\", 'icase':1, 'dup':1}})\n",
                                        completion.CompletionText, completion.DisplayText,
                                        completion.Description.Replace(Environment.NewLine, "\\n").Replace("\"", "''"));            
                    }

                    string res = sb.ToString();

                    Send(res, ref socket);
                    socket.Close();
                }
            }
        }

        private void Send(String sData, ref Socket mySocket)
        {
            Send(Encoding.ASCII.GetBytes(sData), ref mySocket);
        }

        private void Send(Byte[] bytes, ref Socket socket)
        {
            try
            {
                if (socket.Connected)
                {
                    int numBytes;
                    if ((numBytes = socket.Send(bytes, bytes.Length, 0)) == -1)
                        _logger.Error("Socket Error cannot Send Packet");
                    else
                    {
                        _logger.Debug("No. of bytes send " + numBytes);
                    }
                }
                else
                    _logger.Debug("Connection Dropped....");
            }
            catch (Exception e)
            {
                _logger.Error("Error Occurred :  " + e);
            }
        }
    }
}
