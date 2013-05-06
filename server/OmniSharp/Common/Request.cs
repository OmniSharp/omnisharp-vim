using OmniSharp.Solution;

namespace OmniSharp.Common
{
    public class Request
    {
        private string _fileName;
        public int Line { get; set; }
        public int Column { get; set; }
        public string Buffer { get; set; }
        public string FileName
        {
            get { return _fileName; }
            set { _fileName = value.FixPath(); }
        }
    }
}
