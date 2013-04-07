#OmniSharp

OmniSharp is a plugin for Vim to provide IDE like abilities for C#. A list of currently implemented features is provied below.

OmniSharp works both on Windows and on Linux and OS X with Mono.

OmniSharp is just a thin wrapper around the awesome [NRefactory] (https://github.com/icsharpcode/NRefactory) library, so it provides the same
completions as MonoDevelop/SharpDevelop. The server knows nothing about Vim, so could be plugged into most editors fairly easily.

##Features

* Contextual code completion
	* Code documentation is displayed in the preview window when available
	* CamelCase completions are supported, e.g Console.WL(TAB) will complete to Console.WriteLine
* Jump to the definition of a type/variable/method
* Find implementations/derived types
* Find usages
* Contextual code actions
* Rename refactoring
* Lookup type information of an type/variable/method
	* Can be printed to the status line or in the preview window
* Simple syntax error highlighting


##Screenshots
####Auto Complete
![Omnisharp screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/Omnisharp.png)

####Find Usages
![Find Usages screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/FindUsages.png)

####Code Actions
![Code Actions screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/CodeActions.png)

##Installation

Install [Python 2.7.3] (http://www.python.org/download/releases/2.7.3/). If you installed Vim using the windows installer, you will need to install the x86 (32 bit!) version of Python.

Verify that Python is working inside Vim with 

```vim
:python print "hi"
```

Copy the contents of vimfiles into your $VIM\vimfiles directory.

(Optional but highly recommended) Install [SuperTab] (https://github.com/ervandew/supertab) Vim plugin.

### Run the server

	OmniSharp.exe -s (path\to\sln)

OmniSharp listens to requests from Vim on port 2000 by default, so make sure that your firewall is configured to accept requests from localhost on this port.

To get completions, open one of the C# files from the solution within Vim and press Ctrl-X Ctrl-O in Insert mode (or just TAB if you have SuperTab installed). 
Repeat to cycle through completions, or use the cursor keys (eugh!)

Simple syntax error highlighting is automatically performed when saving the current buffer.

To use the other features, you'll want to create key bindings for them. See the example vimrc for more info.



### Example vimrc

```vim
"This is the default value, setting it isn't actually necessary
let g:OmniSharp_host = "http://localhost:2000"

"Set the type lookup function to use the preview window instead of the status line
let g:OmniSharp_typeLookupInPreview = 1

map <F12> :call OmniSharp#GotoDefinition()<cr>
nmap fi :call OmniSharp#FindImplementations()<cr>
nmap fu :call OmniSharp#FindUsages()<cr>
nmap <leader>tt :call OmniSharp#TypeLookup()<cr>
"I find contextual code actions so useful that I have it mapped to the spacebar
nmap <space> :call OmniSharp#GetCodeActions()<cr>

" rename with dialog
nmap nm :call OmniSharp#Rename()<cr>
nmap <F2> :call OmniSharp#Rename()<cr>      
" rename without dialog - with cursor on the symbol to rename... ':Rename newname'
command! -nargs=1 Rename :call OmniSharp#RenameTo("<args>")

"Don't ask to save when changing buffers (i.e. when jumping to a type definition)
set hidden
```


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


