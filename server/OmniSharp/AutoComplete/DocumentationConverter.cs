using System;
using System.Text;
using System.Text.RegularExpressions;
using System.Xml;

namespace OmniSharp.AutoComplete
{
    public static class DocumentationConverter
    {
        private static readonly Regex Whitespace = new Regex(@"\s+");

        /// <summary>
        /// Converts the xml documentation string into a plain text string.
        /// </summary>
        public static string ConvertDocumentation(string xmlDocumentation)
        {
            if (string.IsNullOrEmpty(xmlDocumentation))
                return string.Empty;

            var reader = new System.IO.StringReader("<docroot>" + xmlDocumentation + "</docroot>");
            var xml = new XmlTextReader(reader);
            var ret = new StringBuilder();
            ////Regex whitespace    = new Regex(@"\s+");

            try
            {
                xml.Read();
                do
                {
                    if (xml.NodeType == XmlNodeType.Element)
                    {
                        string elname = xml.Name.ToLowerInvariant();
                        switch (elname)
                        {
                            case "filterpriority":
                                xml.Skip();
                                break;
                            case "remarks":
                                ret.Append(Environment.NewLine);
                                ret.Append("Remarks:");
                                ret.Append(Environment.NewLine);
                                break;
                            case "example":
                                ret.Append(Environment.NewLine);
                                ret.Append("Example:");
                                ret.Append(Environment.NewLine);
                                break;
                            case "exception":
                                ret.Append(Environment.NewLine);
                                ret.Append(GetCref(xml["cref"]));
                                ret.Append(": ");
                                break;
                            case "returns":
                                ret.Append(Environment.NewLine);
                                ret.Append("Returns: ");
                                break;
                            case "see":
                                ret.Append(GetCref(xml["cref"]));
                                ret.Append(xml["langword"]);
                                break;
                            case "seealso":
                                ret.Append(Environment.NewLine);
                                ret.Append("See also: ");
                                ret.Append(GetCref(xml["cref"]));
                                break;
                            case "paramref":
                                ret.Append(xml["name"]);
                                break;
                            case "param":
                                ret.Append(Environment.NewLine);
                                ret.Append(Whitespace.Replace(xml["name"].Trim(), " "));
                                ret.Append(": ");
                                break;
                            case "value":
                                ret.Append(Environment.NewLine);
                                ret.Append("Value: ");
                                ret.Append(Environment.NewLine);
                                break;
                            case "br":
                            case "para":
                                ret.Append(Environment.NewLine);
                                break;
                        }
                    }
                    else if (xml.NodeType == XmlNodeType.Text)
                    {
                        ret.Append(Whitespace.Replace(xml.Value, " "));
                    }
                } while (xml.Read());
            }
            catch (Exception)
            {
                //LoggingService.Debug("Invalid XML documentation: " + ex.Message);
                return xmlDocumentation;
            }
            return ret.ToString();
        }

        private static string GetCref(string cref)
        {
            if (cref == null || cref.Trim().Length == 0)
            {
                return "";
            }
            if (cref.Length < 2)
            {
                return cref;
            }
            if (cref.Substring(1, 1) == ":")
            {
                return cref.Substring(2, cref.Length - 2);
            }
            return cref;
        }
    }
}
