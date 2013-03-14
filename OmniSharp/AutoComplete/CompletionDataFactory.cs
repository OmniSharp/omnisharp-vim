using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using ICSharpCode.NRefactory.CSharp;
using ICSharpCode.NRefactory.CSharp.Completion;
using ICSharpCode.NRefactory.Completion;
using ICSharpCode.NRefactory.Documentation;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.AutoComplete
{
    public class CompletionDataFactory : ICompletionDataFactory
    {
        private readonly string _partialWord;
        private readonly CSharpAmbience _ambience = new CSharpAmbience {ConversionFlags = AmbienceFlags};

        private const ConversionFlags AmbienceFlags =
            ConversionFlags.ShowBody |
            ConversionFlags.ShowParameterList |
            ConversionFlags.ShowParameterNames;

        private string _completionText;
        private string _signature;

        public CompletionDataFactory(string partialWord)
        {
            _partialWord = partialWord;
            
        }


        public ICompletionData CreateEntityCompletionData(IEntity entity)
        {

            _completionText = _signature = entity.Name;
            
            _completionText = _ambience.ConvertEntity(entity).Replace(";", "");
            if (entity is IMethod)
            {
                var method = entity as IMethod;
                GenerateMethodSignature(method);
            }

            ICompletionData completionData = CompletionData(entity);

            Debug.Assert(completionData != null);
            return completionData;
        }

        private ICompletionData CompletionData(IEntity entity)
        {
            ICompletionData completionData = null;
            if (entity.Documentation != null)
            {
                completionData = new CompletionData(_signature, _completionText,
                                                    _signature + Environment.NewLine +
                                                    CodeCompletionItemProvider.ConvertDocumentation(entity.Documentation));
            }
            else
            {
                XmlDocumentationProvider docProvider = null;
                if (entity.ParentAssembly.AssemblyName != null)
                {
                    docProvider =
                        XmlDocumentationProviderFactory.Get(entity.ParentAssembly.AssemblyName);
                }
                if (docProvider != null)
                {
                    DocumentationComment documentationComment = docProvider.GetDocumentation(entity);
                    if (documentationComment != null)
                    {
                        var documentation = _signature + Environment.NewLine +
                                            CodeCompletionItemProvider.ConvertDocumentation(
                                                documentationComment.Xml.Text);
                        completionData = new CompletionData(_signature, _completionText, documentation);
                    }
                    else
                    {
                        completionData = new CompletionData(_signature, _completionText, "No documentation");
                    }
                }
                else
                {
                    completionData = new CompletionData(_signature, _completionText, _signature);
                }
            }
            return completionData;
        }

        private void GenerateMethodSignature(IMethod method)
        {
            _signature = _ambience.ConvertEntity(method).Replace(";", "");
            _completionText = _signature.Remove(_signature.IndexOf('(') + 1);
            if (!method.Parameters.Any())
            {
                _completionText += ")";
            }
        }

        private bool ShouldProcess(IEntity entity)
        {
            var name = entity.Name;
            if (entity.EntityType == EntityType.Constructor)
            {
                name = entity.DeclaringType.Name;
            }

            return name.IsValidCompletionFor(_partialWord);
        }

        public ICompletionData CreateEntityCompletionData(IEntity entity, string text)
        {
            return new CompletionData(text);
        }

        public ICompletionData CreateTypeCompletionData(IType type, bool showFullName, bool isInAttributeContext)
        {
            var completion = new CompletionData(type.Name);
            foreach (var constructor in type.GetConstructors())
            {
                completion.AddOverload(CreateEntityCompletionData(constructor));
            }
            return completion;
        }

        public ICompletionData CreateMemberCompletionData(IType type, IEntity member)
        {
            return new CompletionData(type.Name);
        }

        public ICompletionData CreateLiteralCompletionData(string title, string description, string insertText)
        {
            return new CompletionData(title, description);
        }

        public ICompletionData CreateNamespaceCompletionData(INamespace name)
        {
            return new CompletionData(name.Name, name.FullName);
        }

        public ICompletionData CreateVariableCompletionData(IVariable variable)
        {
            return new CompletionData(variable.Name);
        }

        public ICompletionData CreateVariableCompletionData(ITypeParameter parameter)
        {
            return new CompletionData(parameter.Name);
        }

        public ICompletionData CreateEventCreationCompletionData(string varName, IType delegateType, IEvent evt,
                                                                 string parameterDefinition,
                                                                 IUnresolvedMember currentMember,
                                                                 IUnresolvedTypeDefinition currentType)
        {
            return new CompletionData(varName);
        }

        public ICompletionData CreateNewOverrideCompletionData(int declarationBegin, IUnresolvedTypeDefinition type,
                                                               IMember m)
        {
            return new CompletionData(m.Name);
        }

        public ICompletionData CreateNewPartialCompletionData(int declarationBegin, IUnresolvedTypeDefinition type,
                                                              IUnresolvedMember m)
        {
            return new CompletionData(m.Name);
        }

        public IEnumerable<ICompletionData> CreateCodeTemplateCompletionData()
        {
            return Enumerable.Empty<ICompletionData>();
        }

        public IEnumerable<ICompletionData> CreatePreProcessorDefinesCompletionData()
        {
            yield return new CompletionData("DEBUG");
            yield return new CompletionData("TEST");
        }

        public ICompletionData CreateImportCompletionData(IType type, bool useFullName)
        {
            throw new NotImplementedException();
        }
    }
}
