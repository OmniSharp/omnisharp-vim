using System.Text.RegularExpressions;
using OmniSharp.Common;

namespace OmniSharp.Build
{
    public class BuildLogParser
    {

        public QuickFix Parse(string line)
        {
            if (!line.Contains("error CS"))
                return null;

            var match = GetMatches(line, @".*(Source file '(.*)'.*)");
            if(match.Matched)
            {
                var matches = match.Matches;
                var quickFix = new QuickFix
                    {
                        FileName = matches[0].Groups[2].Value,
                        Text = matches[0].Groups[1].Value.Replace("'", "''")
                    };

                return quickFix;
            }

            match = GetMatches(line, @"\s+(.*cs)\((\d+),(\d+)\).*error CS\d+: (.*) \[");
            if(match.Matched)
            {
                var matches = match.Matches;
                var quickFix = new QuickFix
                    {
                        FileName = matches[0].Groups[1].Value,
                        Line = int.Parse(matches[0].Groups[2].Value),
                        Column = int.Parse(matches[0].Groups[3].Value),
                        Text = matches[0].Groups[4].Value.Replace("'", "''")
                    };

                return quickFix;
            }
            return null;
        }

        private Match GetMatches(string line, string regex)
        {
            var match = new Match();
            var matches = Regex.Matches(line, regex, RegexOptions.Compiled);
            if (matches.Count > 0 && !Regex.IsMatch(line, @"\d+>"))
            {
                match.Matched = true;
                match.Matches = matches;
            }
            return match;
        }

        class Match
        {
            public bool Matched { get; set; }
            public MatchCollection Matches { get; set; }
        }
    }
}