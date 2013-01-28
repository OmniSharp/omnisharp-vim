#OmniSharp

OmniSharp is an omnicomplete (intellisense) plugin for C# to use with Vim.

This is currently working on Windows only, but will only require minor tweaks to run under Linux/OSX/Mono (pull requests welcome!)

OmniSharp is just a thin wrapper around the awesome [NRefactory] (https://github.com/icsharpcode/NRefactory) library, so it provides the same
completions as MonoDevelop/SharpDevelop. 

##Installation

Install [Python 2.7.3] (http://www.python.org/download/releases/2.7.3/)

Verify that Python is working inside Vim with :python print "hi". You may need to log out and back in again.

Copy the contents of vimfiles into your $VIM\vimfiles directory

(Optional but highly recommended) Install [SuperTab] (https://github.com/ervandew/supertab) Vim plugin

## Run the server

OmniSharp.exe -s (path\to\sln)

To get completions, open one of the C# solution files within Vim and press Ctrl-X Ctrl-O in Insert mode (or just TAB if you have SuperTab installed)

###Disclaimer

This project is very much incomplete/buggy. 

It may eat your code.

