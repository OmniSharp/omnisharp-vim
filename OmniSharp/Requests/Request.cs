namespace OmniSharp.Requests
{
    public abstract class Request
    {
        public int CursorPosition { get; set; }
        public string Buffer { get; set; }
        public string FileName { get; set; }
    }
}