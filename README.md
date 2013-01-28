#OmniSharp

OmniSharp is an omnicomplete (intellisense) plugin for c# to use with Vim.

This is currently working on Windows only, but will only require minor tweaks to run under Linux/Mono (pull requests welcome!)

OmniSharp is just a thin wrapper around the awesome [NRefactory] (https://github.com/icsharpcode/NRefactory) library, so it provides the same
completions as MonoDevelop/SharpDevelop. 

##Installation

Install [Python 2.7.3] (http://www.python.org/download/releases/2.7.3/)

Copy the contents of vimfiles into your $VIM\vimfiles directory

(Optional but highly recommended) Install [SuperTab] (https://github.com/ervandew/supertab) Vim plugin

## Run the server

OmniSharp.exe -s (path\to\sln)

To get completions press Ctrl-X Ctrl-O in Insert mode (or just <TAB> if you have SuperTab installed)

###Disclaimer


This project is very much incomplete/buggy. 
It may eat your code.
