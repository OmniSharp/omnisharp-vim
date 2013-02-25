﻿namespace OmniSharp.Requests
{
    public abstract class Request
    {
        public int CursorLine { get; set; }
        public int CursorColumn { get; set; }
        public string Buffer { get; set; }
        public string FileName { get; set; }
    }
}