using OmniSharp.Solution;

namespace OmniSharp.AddReference
{
    public interface IAddToProjectProcessor
    {
        AddReferenceResponse AddReference(IProject project, string reference);
    }
}