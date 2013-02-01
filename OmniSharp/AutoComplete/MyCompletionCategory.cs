using System;
using ICSharpCode.NRefactory.Completion;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.AutoComplete
{
    public class MyCompletionsCategory : CompletionCategory
    {
        public MyCompletionsCategory(EntityType entityType)
        {
            DisplayText = GetVimKind(entityType);
        }

        public MyCompletionsCategory()
        {
            DisplayText = " ";
        }

        private string GetVimKind(EntityType entityType)
        {
    //        v	variable
    //f	function or method
    //m	member of a struct or class
            switch(entityType)
            {
                case(EntityType.Method):
                    return "f";
                case(EntityType.Field):
                    return "v";
                case(EntityType.Property):
                    return "m";
            }
            return " ";
        }

        public override int CompareTo(CompletionCategory other)
        {
            return String.CompareOrdinal(this.DisplayText, other.DisplayText);
        }
    }
}
