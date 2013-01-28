namespace OmniSharp
{
    public class AutocompleteRequest
    {
        public int CursorPosition { get; set; }
        public string WordToComplete { get; set; }
        public string Buffer { get; set; }
        public string FileName { get; set; }
    }
}