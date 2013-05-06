namespace OmniSharp.Tests.Rename
{
    public class Buffer
    {
        public string Text { get; set; }
        public string Filename { get; set; }

        public Buffer(string text, string filename)
        {
            Text = text;
            Filename = filename;
        }
    }
}