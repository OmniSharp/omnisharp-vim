using System.Collections.Generic;
using System.Text;
using ICSharpCode.NRefactory.TypeSystem;
using ICSharpCode.NRefactory.TypeSystem.Implementation;

namespace OmniSharp.AutoComplete
{
    public class CompletionBuilders
    {
        private bool ShowParameterList;
        private bool IncludeHtmlMarkup;
        private bool ShowModifiers;
        private bool ShowDefinitionKeyWord;
        private bool ShowReturnType;
        private bool IncludeBody;
        private bool UseFullyQualifiedMemberNames;
        private bool ShowTypeParameterList;

        public static IDictionary<string, string> TypeConversionTable
        {
            get { return ICSharpCode.NRefactory.Ast.TypeReference.PrimitiveTypesCSharpReverse; }
        }

        //// EntityDeclaration
        //// AbstractResolvedEntity
        //public string Convert(TypeDeclaration c)
        // {
        //     //CheckThread();

        //     StringBuilder builder = new StringBuilder();

        //     //builder.Append(ConvertAccessibility(c.Modifiers));

        //     if (IncludeHtmlMarkup)
        //     {
        //         builder.Append("<i>");
        //     }

        //     if (ShowModifiers)
        //     {
        //         if (c.IsStatic)
        //         {
        //             builder.Append("static ");
        //         }
        //         else if (c.IsSealed)
        //         {
        //             switch (c.ClassType)
        //             {
        //                 //case ClassType.Delegate:
        //                 case ClassType.Struct:
        //                 case ClassType.Enum:
        //                     break;

        //                 default:
        //                     builder.Append("sealed ");
        //                     break;
        //             }
        //         }
        //         else if (c.IsAbstract && c.ClassType != ClassType.Interface)
        //         {
        //             builder.Append("abstract ");
        //         }
        //         //#if DEBUG
        //         //                if (c.HasCompoundClass)
        //         //                    builder.Append("multiple_parts ");
        //         //                if (c is CompoundClass)
        //         //                {
        //         //                    builder.Append("compound{");
        //         //                    builder.Append(string.Join(",", (c as CompoundClass).Parts.Select(p => p.SyntaxTree.FileName).ToArray()));
        //         //                    builder.Append("} ");
        //         //                }
        //         //#endif
        //     }

        //     //if (IncludeHtmlMarkup)
        //     //{
        //     //    builder.Append("</i>");
        //     //}

        //     if (ShowDefinitionKeyWord)
        //     {
        //         switch (c.ClassType)
        //         {
        //             //case ClassType.Delegate:
        //             //    builder.Append("delegate");
        //             //    break;
        //             case ClassType.Class:
        //                 //case ClassType.Module:
        //                 builder.Append("class");
        //                 break;
        //             case ClassType.Struct:
        //                 builder.Append("struct");
        //                 break;
        //             case ClassType.Interface:
        //                 builder.Append("interface");
        //                 break;
        //             case ClassType.Enum:
        //                 builder.Append("enum");
        //                 break;
        //         }
        //         builder.Append(' ');
        //     }
        //     if (ShowReturnType && c.ClassType == ClassType.Delegate)
        //     {
        //         foreach (IMethod m in c.Methods)
        //         {
        //             if (m.Name != "Invoke") continue;

        //             builder.Append(Convert(m.ReturnType));
        //             builder.Append(' ');
        //         }
        //     }

        //     AppendClassNameWithTypeParameters(builder, c, UseFullyQualifiedMemberNames, true, null);

        //     if (ShowParameterList && c.ClassType == ClassType.Delegate)
        //     {
        //         builder.Append(" (");
        //         //if (IncludeHtmlMarkup) builder.Append("<br>");

        //         foreach (IMethod m in c.Methods)
        //         {
        //             if (m.Name != "Invoke") continue;

        //             for (int i = 0; i < m.Parameters.Count; ++i)
        //             {
        //                 //if (IncludeHtmlMarkup) builder.Append("&nbsp;&nbsp;&nbsp;");

        //                 builder.Append(Convert(m.Parameters[i]));
        //                 if (i + 1 < m.Parameters.Count) builder.Append(", ");

        //                 //if (IncludeHtmlMarkup) builder.Append("<br>");
        //             }
        //         }
        //         builder.Append(')');

        //     }
        //     else if (ShowInheritanceList)
        //     {
        //         if (c.BaseTypes.Count > 0)
        //         {
        //             builder.Append(" : ");
        //             for (int i = 0; i < c.BaseTypes.Count; ++i)
        //             {
        //                 builder.Append(c.BaseTypes[i]);
        //                 if (i + 1 < c.BaseTypes.Count)
        //                 {
        //                     builder.Append(", ");
        //                 }
        //             }
        //         }
        //     }

        //     if (IncludeBody)
        //     {
        //         builder.Append("\n{");
        //     }

        //     return builder.ToString();
        // }

        //private char ConvertAccessibility(Modifiers modifiers)
        //{
        //    return 'c';
        //}

        //void AppendClassNameWithTypeParameters(StringBuilder builder, IClass c, bool fullyQualified, bool isConvertingClassName, IList<IReturnType> typeArguments)
        // {

        //     if (fullyQualified)
        //     {
        //         if (c.DeclaringType != null)
        //         {
        //             AppendClassNameWithTypeParameters(builder, c.DeclaringType, fullyQualified, false, typeArguments);
        //             builder.Append('.');
        //             builder.Append(c.Name);
        //         }
        //         else
        //         {
        //             builder.Append(c.FullyQualifiedName);
        //         }
        //     }
        //     else
        //     {
        //         builder.Append(c.Name);
        //     }
        //     if (isConvertingClassName && IncludeHtmlMarkup)
        //     {
        //         builder.Append("</b>");
        //     }
        //     // skip type parameters that belong to declaring types (in DOM, inner classes repeat type parameters from outer classes)
        //     int skippedTypeParameterCount = c.DeclaringType != null ? c.DeclaringType.TypeParameters.Count : 0;
        //     // show type parameters for classes only if ShowTypeParameterList is set; but always show them in other cases.
        //     if ((ShowTypeParameterList || !isConvertingClassName) && c.TypeParameters.Count > skippedTypeParameterCount)
        //     {
        //         builder.Append('<');
        //         for (int i = skippedTypeParameterCount; i < c.TypeParameters.Count; ++i)
        //         {
        //             if (i > skippedTypeParameterCount)
        //                 builder.Append(", ");
        //             if (typeArguments != null && i < typeArguments.Count)
        //                 AppendReturnType(builder, typeArguments[i], false);
        //             else
        //                 builder.Append(ConvertTypeParameter(c.TypeParameters[i]));
        //         }
        //         builder.Append('>');
        //     }
        // }

        // public override string ConvertEnd(IClass c)
        // {
        //     return "}";
        // }

        // public string Convert(IField field)
        // {
        //     //CheckThread();

        //     StringBuilder builder = new StringBuilder();

        //     builder.Append(ConvertAccessibility(field.Modifiers));

        //     //if (IncludeHtmlMarkup)
        //     //{
        //     //    builder.Append("<i>");
        //     //}

        //     if (ShowModifiers)
        //     {
        //         if (field.IsConst)
        //         {
        //             builder.Append("const ");
        //         }
        //         else if (field.IsStatic)
        //         {
        //             builder.Append("static ");
        //         }

        //         if (field.IsNew)
        //         {
        //             builder.Append("new ");
        //         }
        //         if (field.IsReadonly)
        //         {
        //             builder.Append("readonly ");
        //         }
        //         if ((field.Modifiers & ModifierEnum.Volatile) == ModifierEnum.Volatile)
        //         {
        //             builder.Append("volatile ");
        //         }
        //     }

        //     if (IncludeHtmlMarkup)
        //     {
        //         builder.Append("</i>");
        //     }

        //     if (field.ReturnType != null && ShowReturnType)
        //     {
        //         builder.Append(Convert(field.ReturnType));
        //         builder.Append(' ');
        //     }

        //     AppendTypeNameForFullyQualifiedMemberName(builder, field.DeclaringTypeReference);

        //     if (IncludeHtmlMarkup)
        //     {
        //         builder.Append("<b>");
        //     }

        //     builder.Append(field.Name);

        //     if (IncludeHtmlMarkup)
        //     {
        //         builder.Append("</b>");
        //     }

        //     if (IncludeBody) builder.Append(";");

        //     return builder.ToString();
        // }

        // public string Convert(IProperty property)
        // {
        //     //CheckThread();

        //     StringBuilder builder = new StringBuilder();

        //     builder.Append(ConvertAccessibility(property.Modifiers));

        //     if (ShowModifiers)
        //     {
        //         builder.Append(GetModifier(property));
        //     }

        //     if (property.ReturnType != null && ShowReturnType)
        //     {
        //         builder.Append(Convert(property.ReturnType));
        //         builder.Append(' ');
        //     }

        //     AppendTypeNameForFullyQualifiedMemberName(builder, property.DeclaringTypeReference);

        //     if (property.IsIndexer)
        //     {
        //         builder.Append("this");
        //     }
        //     else
        //     {
        //         //if (IncludeHtmlMarkup)
        //         //{
        //         //    builder.Append("<b>");
        //         //}
        //         builder.Append(property.Name);
        //         //if (IncludeHtmlMarkup)
        //         //{
        //         //    builder.Append("</b>");
        //         //}
        //     }

        //     if (property.Parameters.Count > 0 && ShowParameterList)
        //     {
        //         builder.Append(property.IsIndexer ? '[' : '(');
        //         //if (IncludeHtmlMarkup) builder.Append("<br>");

        //         for (int i = 0; i < property.Parameters.Count; ++i)
        //         {
        //             //if (IncludeHtmlMarkup) builder.Append("&nbsp;&nbsp;&nbsp;");
        //             builder.Append(Convert(property.Parameters[i]));
        //             if (i + 1 < property.Parameters.Count)
        //             {
        //                 builder.Append(", ");
        //             }
        //             //if (IncludeHtmlMarkup) builder.Append("<br>");
        //         }

        //         builder.Append(property.IsIndexer ? ']' : ')');
        //     }

        //     //if (IncludeBody)
        //     {
        //         builder.Append(" { ");

        //         if (property.CanGet)
        //         {
        //             builder.Append("get; ");
        //         }
        //         if (property.CanSet)
        //         {
        //             builder.Append("set; ");
        //         }

        //         builder.Append(" } ");
        //     }

        //     return builder.ToString();
        // }

        public string MethodName(IMethod m)
        {
            if (m.IsConstructor && m.DeclaringType != null)
            {
                return m.DeclaringType.Name;
            }
            else
            {
                return m.Name;
            }
        }
        public string Convert(IMethod m)
        {

            var builder = new StringBuilder();
            //builder.Append(ConvertAccessibility(m..Modifiers));

            //if (ShowModifiers)
            //{
            //    builder.Append(GetModifier(m));
            //}

            //if (!m.IsConstructor && m.ReturnType != null)
            //{
            //    builder.Append(Convert(m.ReturnType));
            //    builder.Append(' ');
            //}

            //AppendTypeNameForFullyQualifiedMemberName(builder, m.DeclaringTypeReference);

            builder.Append(MethodName(m));

            

            //if (ShowTypeParameterList && m.TypeParameters.Count > 0)
            //{
            //    builder.Append('<');
            //    for (int i = 0; i < m.TypeParameters.Count; ++i)
            //    {
            //        if (i > 0) builder.Append(", ");
            //        builder.Append(ConvertTypeParameter(m.TypeParameters[i]));
            //    }
            //    builder.Append('>');
            //}

            //if (ShowParameterList)
            {
                builder.Append("(");
                //if (IncludeHtmlMarkup) builder.Append("<br>");

                if (m.IsExtensionMethod) builder.Append("this ");

                for (int i = 0; i < m.Parameters.Count; ++i)
                {
                    //if (IncludeHtmlMarkup) builder.Append("&nbsp;&nbsp;&nbsp;");
                    builder.Append(Convert(m.Parameters[i]));
                    if (i + 1 < m.Parameters.Count)
                    {
                        builder.Append(", ");
                    }
                    //if (IncludeHtmlMarkup) builder.Append("<br>");
                }

                builder.Append(')');
            }

            ////if (IncludeBody)
            //{
            //    if (m.DeclaringType != null)
            //    {
            //        //if (m.DeclaringType.ClassType == ClassType.Interface)
            //        //{
            //        //    builder.Append(";");
            //        //}
            //        //else
            //        {
            //            builder.Append(" {");
            //        }
            //    }
            //    else
            //    {
            //        builder.Append(" {");
            //    }
            //}
            return builder.ToString();
        }

        public string Convert(IParameter param)
        {
            //CheckThread();

            StringBuilder builder = new StringBuilder();

            //if (IncludeHtmlMarkup)
            //{
            //    builder.Append("<i>");
            //}

            if (param.IsRef)
            {
                builder.Append("ref ");
            }
            else if (param.IsOut)
            {
                builder.Append("out ");
            }
            else if (param.IsParams)
            {
                builder.Append("params ");
            }

            

            builder.Append(Convert(param.Type));
            //builder.Append(param.Type);

            //if (ShowParameterNames)
            {
                builder.Append(' ');
                builder.Append(param.Name);
            }
            return builder.ToString();
        }

        private string Convert(IType type)
        {
            return GetIntrinsicTypeName(type);
        }

        private string GetIntrinsicTypeName(IType dotNetTypeName)
        {
            string shortName;
            string lookup;

            if(dotNetTypeName is UnknownType)
            {
                lookup = dotNetTypeName.Namespace + "." + dotNetTypeName.Name;
            }
            else
            {
                lookup = dotNetTypeName.ReflectionName;
            }

            if (TypeConversionTable.TryGetValue(lookup, out shortName))
            {
                return shortName;
            }
            return dotNetTypeName.Name;
        }
    }
}
