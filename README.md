#OmniSharp

OmniSharp is an omnicomplete (intellisense) plugin for C# to use with Vim.
                                                               
Code documentation is displayed in the scratch window.

CamelCase completions are supported, e.g Console.WL(TAB) will complete to Console.WriteLine

This is currently working on Windows only, but will only require minor tweaks to run under Linux/OSX/Mono (pull requests welcome!)

OmniSharp is just a thin wrapper around the awesome [NRefactory] (https://github.com/icsharpcode/NRefactory) library, so it provides the same
completions as MonoDevelop/SharpDevelop. 

New! OmniSharp now also includes a "go to definition" function that doesn't require CTAGS.

##Screenshot
![Omnisharp screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/Omnisharp.png)


##Installation

Install [Python 2.7.3] (http://www.python.org/download/releases/2.7.3/). If you installed Vim using the windows installer, you will need to install the x86 version of Python.

Verify that Python is working inside Vim with :python print "hi". 

Copy the contents of vimfiles into your $VIM\vimfiles directory.

(Optional but highly recommended) Install [SuperTab] (https://github.com/ervandew/supertab) Vim plugin.

## Run the server

OmniSharp.exe -s (path\to\sln)

OmniSharp listens to requests from Vim on port 2000 by default, so make sure that your firewall is configured to accept requests from localhost on this port.

To get completions, open one of the C# solution files within Vim and press Ctrl-X Ctrl-O in Insert mode (or just TAB if you have SuperTab installed)

To use the "go to definition" function, add a mapping to call the GotoDefinition function in your $VIMRC file, such as :-

	map <F12> :call GotoDefinition()<cr>

You'll also probably want to "set hidden", otherwise Vim will ask you to save the current buffer when you try and navigate to a new one.

	set hidden
    


###Disclaimer

This project is very much incomplete/buggy. 

It may eat your code.


#####TODO

- Refactorings
- Add files to project
- Highlight syntax errors as you type
- Fix bugs

Pull requests welcome!

