#OmniSharp

OmniSharp is a plugin for Vim to provide IDE like abilities for C#. It currently supports omnicomplete(intellisense), contextual code actions,
go to definition, find usages and go to implementation.
                                                               
Code documentation is displayed in the scratch window.

CamelCase completions are supported, e.g Console.WL(TAB) will complete to Console.WriteLine

OmniSharp works both on Windows and on Linux and OS X with Mono. To run it with Mono you will probably have to use [IOMap] (http://www.mono-project.com/IOMap) since the solution and project files typically use Windows-styled paths.

OmniSharp is just a thin wrapper around the awesome [NRefactory] (https://github.com/icsharpcode/NRefactory) library, so it provides the same
completions as MonoDevelop/SharpDevelop. The server knows nothing about Vim, so could be plugged into most editors fairly easily.


##Screenshots
####Auto Complete
![Omnisharp screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/Omnisharp.png)

####Find Usages
![Find Usages screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/FindUsages.png)

####Code Actions
![Code Actions screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/CodeActions.png)

##Installation

Install [Python 2.7.3] (http://www.python.org/download/releases/2.7.3/). If you installed Vim using the windows installer, you will need to install the x86 (32 bit!) version of Python.

Verify that Python is working inside Vim with :python print "hi". 

Copy the contents of vimfiles into your $VIM\vimfiles directory.

(Optional but highly recommended) Install [SuperTab] (https://github.com/ervandew/supertab) Vim plugin.

## Run the server

	OmniSharp.exe -s (path\to\sln)

OmniSharp listens to requests from Vim on port 2000 by default, so make sure that your firewall is configured to accept requests from localhost on this port.

To get completions, open one of the C# solution files within Vim and press Ctrl-X Ctrl-O in Insert mode (or just TAB if you have SuperTab installed). 
Repeat to cycle through completions, or use the cursor keys (eugh!)

To use the "go to definition" function, add a mapping to call the GotoDefinition function in your $VIMRC file, such as :-

	map <F12> :call GotoDefinition()<cr>

or

	nmap gd :call GotoDefinition()<cr>

To use the "Find implementations / derived types" function, add the following mapping :-

	nmap fi :call FindImplementations()<cr>

To use the "Find Usages" function, add the following mapping :-

	nmap fu :call FindUsages()<cr>

I find contextual code actions so useful that I have it mapped to the spacebar :-

	nmap <space> :call GetCodeActions()<cr>

You'll also probably want to "set hidden" if it's not already set, otherwise Vim will ask you to save the current buffer when you try and navigate to a new one.

	set hidden

Simple syntax error highlighting is performed when saving the current buffer.


###Disclaimer

This project is very much incomplete/buggy. 

It may eat your code.


#####TODO

- Refactorings
- Add files to project
- Highlight syntax errors as you type
- Start the server from within Vim and auto discover the solution file where possible
- Fix bugs

Pull requests welcome!


