namespace OmniSharp.FindUsages
{
    public class Usage
    {
        public string FileName { get; set; }
        public int Line { get; set; }
        public int Column { get; set; }
        public string Text { get; set; }
    }
}