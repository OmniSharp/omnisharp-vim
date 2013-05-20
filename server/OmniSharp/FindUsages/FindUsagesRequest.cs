using OmniSharp.Common;

namespace OmniSharp.FindUsages
{
    public class FindUsagesRequest : Request
    {
        private int _maxWidth = 100;

        public int MaxWidth
        {
            get { return _maxWidth; }
            set { _maxWidth = value; }
        }
    }
}