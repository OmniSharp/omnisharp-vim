using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public interface IReferenceProcessor
    {
        AddReferenceResponse AddReference(IProject project, string reference);
    }
}