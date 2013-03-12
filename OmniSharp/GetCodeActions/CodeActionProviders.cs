using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using ICSharpCode.NRefactory.CSharp.Refactoring;

namespace OmniSharp.GetCodeActions
{
    public class CodeActionProviders
    {
        public IEnumerable<ICodeActionProvider> GetProviders()
        {
            var types = Assembly.GetAssembly(typeof(ICodeActionProvider))
                                .GetTypes()
                                .Where(t => typeof(ICodeActionProvider).IsAssignableFrom(t));

            IEnumerable<ICodeActionProvider> providers =
                types
                    .Where(type => !type.IsInterface && !type.ContainsGenericParameters) //TODO: handle providers with generic params 
                    .Select(type => (ICodeActionProvider) Activator.CreateInstance(type));

            return providers;
        }
    }
}