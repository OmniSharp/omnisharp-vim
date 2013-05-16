using System.Collections.Generic;
using System.Text.RegularExpressions;
using ICSharpCode.NRefactory.Completion;

namespace OmniSharp.AutoComplete
{
    public class CompletionData
        : ICompletionData
    {
        private readonly ICollection<ICompletionData> _overloadedData 
            = new List<ICompletionData>();

        private string _description;
        private string _displayText;

        public CompletionData(string text)
        {
            DisplayText = CompletionText = Description = text;
        }

        public CompletionData(string text, string description)
        {
            CompletionText = DisplayText = text;
            Description = description ?? text;
        }

        public CompletionData(string displayText, string completionText, string description)
        {
            DisplayText = displayText;
            CompletionText = completionText;
            Description = description ?? displayText;
        }

        public void AddOverload(ICompletionData data)
        {
            _overloadedData.Add(data);
        }

        public CompletionCategory CompletionCategory { get; set; }

        public string DisplayText
        {
            get { return _displayText; }
            set { _displayText = RemoveExtensionMethodParameter(value); }
        }

        private static string RemoveExtensionMethodParameter(string completion)
        {
            return Regex.Replace(completion, @"this\s+[a-zA-Z0-9<>]+\s+[a-zA-Z0-9]+,?\s?", "", RegexOptions.Compiled);
        }

        public string Description
        {
            get { return _description; }
            set { _description = value.Replace("\"", "''"); }
        }

        public string CompletionText { get; set; }

        public DisplayFlags DisplayFlags { get; set; }

        public bool HasOverloads
        {
            get { return _overloadedData.Count > 0; }
        }

        public IEnumerable<ICompletionData> OverloadedData
        {
            get { return _overloadedData; }
        }

        public override string ToString()
        {
            return _description;
        }
    }
}
