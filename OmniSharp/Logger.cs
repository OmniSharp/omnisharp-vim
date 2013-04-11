using System;

namespace OmniSharp
{
    public class Logger
    {
        public void Debug(object message)
        {
            Console.WriteLine(message);
		}
        
        public void Error(object message)
        {
            Console.WriteLine(message);
        }
    }
}
