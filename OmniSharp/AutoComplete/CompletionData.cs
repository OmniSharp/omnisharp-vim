using System;
using System.Collections.Generic;
using ICSharpCode.NRefactory.Completion;

namespace OmniSharp.AutoComplete
{
    public class CompletionDataDto
    {
        public CompletionDataDto() { } // for deserialisation

        public CompletionDataDto(ICompletionData d)
        {
            DisplayText = d.DisplayText;
            CompletionText = d.CompletionText;
            Description = d.Description;
        }

        public string CompletionText { get; set; }
        public string Description { get; set; }
        public string DisplayText { get; set; }
    }

    public class CompletionData
        : ICompletionData
    {
        private readonly ICollection<ICompletionData> _overloadedData 
            = new List<ICompletionData>();

        private string _description;

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

        public string DisplayText { get; set; }

        public string Description
        {
            get { return _description; }
            set { _description = value.Replace(Environment.NewLine, "\\n").Replace("\"", "''"); }
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
