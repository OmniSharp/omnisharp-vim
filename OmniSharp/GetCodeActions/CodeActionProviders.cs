using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using ICSharpCode.NRefactory.CSharp.Refactoring;

namespace OmniSharp.GetCodeActions
{
    public class CodeActionProviders
    {
        private static IEnumerable<ICodeActionProvider> _providers;

        public CodeActionProviders()
        {
            var types = Assembly.GetAssembly(typeof(ICodeActionProvider))
                                .GetTypes();

            var providerTypes = types.Where(t => typeof(ICodeActionProvider).IsAssignableFrom(t));

            IEnumerable<ICodeActionProvider> providers =
                providerTypes
                    .Where(type => !type.IsInterface)
                    .Where(type => !type.ContainsGenericParameters)
                    .Select(type => (ICodeActionProvider)Activator.CreateInstance(type));

            _providers = providers;
        }

        public static IEnumerable<ICodeActionProvider> Providers { get { return _providers; } }

        
    }
}