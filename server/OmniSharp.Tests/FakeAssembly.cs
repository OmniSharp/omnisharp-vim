using System;
using ICSharpCode.NRefactory.TypeSystem;

namespace OmniSharp.Tests
{
    public class FakeAssembly : IAssemblyReference
    {
        private readonly string _assembly;

        public FakeAssembly(string assembly)
        {
            _assembly = assembly;
        }

        public string AssemblyPath { get { return _assembly; } }

        public IAssembly Resolve(ITypeResolveContext context)
        {
            throw new NotImplementedException();
        }
    }
}