namespace OmniSharp.CodeFormat
{
    public class CodeFormatResponse     
    {
        public CodeFormatResponse(string buffer)
        {
            Buffer = buffer;
        }

        public string Buffer { get; private set; }
    }
}