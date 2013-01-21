// Copyright (c) AlphaSierraPapa for the SharpDevelop Team (for details please see \doc\copyright.txt)
// This code is distributed under the GNU LGPL (for details please see \doc\license.txt)

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Text;
using ICSharpCode.NRefactory.CSharp;

namespace ICSharpCode.NRefactory.Ast
{
    public class TypeReference 
    {
       
        #region Static primitive type list
        static Dictionary<string, string> types = new Dictionary<string, string>();
        static Dictionary<string, string> vbtypes = new Dictionary<string, string>(StringComparer.InvariantCultureIgnoreCase);
        static Dictionary<string, string> typesReverse = new Dictionary<string, string>();
        static Dictionary<string, string> vbtypesReverse = new Dictionary<string, string>();

        static TypeReference()
        {
            // C# types
            types.Add("bool", "System.Boolean");
            types.Add("byte", "System.Byte");
            types.Add("char", "System.Char");
            types.Add("decimal", "System.Decimal");
            types.Add("double", "System.Double");
            types.Add("float", "System.Single");
            types.Add("int", "System.Int32");
            types.Add("long", "System.Int64");
            types.Add("object", "System.Object");
            types.Add("sbyte", "System.SByte");
            types.Add("short", "System.Int16");
            types.Add("string", "System.String");
            types.Add("uint", "System.UInt32");
            types.Add("ulong", "System.UInt64");
            types.Add("ushort", "System.UInt16");
            types.Add("void", "System.Void");

            // VB.NET types
            vbtypes.Add("Boolean", "System.Boolean");
            vbtypes.Add("Byte", "System.Byte");
            vbtypes.Add("SByte", "System.SByte");
            vbtypes.Add("Date", "System.DateTime");
            vbtypes.Add("Char", "System.Char");
            vbtypes.Add("Decimal", "System.Decimal");
            vbtypes.Add("Double", "System.Double");
            vbtypes.Add("Single", "System.Single");
            vbtypes.Add("Integer", "System.Int32");
            vbtypes.Add("Long", "System.Int64");
            vbtypes.Add("UInteger", "System.UInt32");
            vbtypes.Add("ULong", "System.UInt64");
            vbtypes.Add("Object", "System.Object");
            vbtypes.Add("Short", "System.Int16");
            vbtypes.Add("UShort", "System.UInt16");
            vbtypes.Add("String", "System.String");

            foreach (KeyValuePair<string, string> pair in types)
            {
                typesReverse.Add(pair.Value, pair.Key);
            }
            foreach (KeyValuePair<string, string> pair in vbtypes)
            {
                vbtypesReverse.Add(pair.Value, pair.Key);
            }
        }

        /// <summary>
        /// Gets a shortname=>full name dictionary of C# types.
        /// </summary>
        public static IDictionary<string, string> PrimitiveTypesCSharp
        {
            get { return types; }
        }

        /// <summary>
        /// Gets a shortname=>full name dictionary of VB types.
        /// </summary>
        public static IDictionary<string, string> PrimitiveTypesVB
        {
            get { return vbtypes; }
        }

        /// <summary>
        /// Gets a full name=>shortname dictionary of C# types.
        /// </summary>
        public static IDictionary<string, string> PrimitiveTypesCSharpReverse
        {
            get { return typesReverse; }
        }

        /// <summary>
        /// Gets a full name=>shortname dictionary of VB types.
        /// </summary>
        public static IDictionary<string, string> PrimitiveTypesVBReverse
        {
            get { return vbtypesReverse; }
        }


        static string GetSystemType(string type)
        {
            if (types == null) return type;

            string systemType;
            if (types.TryGetValue(type, out systemType))
            {
                return systemType;
            }
            if (vbtypes.TryGetValue(type, out systemType))
            {
                return systemType;
            }
            return type;
        }
        #endregion
    }
}
