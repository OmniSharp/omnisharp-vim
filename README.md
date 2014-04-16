![OmniSharp](logo.jpg)

#OmniSharp

OmniSharp is a plugin for Vim to provide IDE like abilities for C#. A list of currently implemented features is provided below.

OmniSharp works both on Windows and on Linux and OS X with Mono.

OmniSharp is just a thin wrapper around the awesome [NRefactory] (https://github.com/icsharpcode/NRefactory) library, so it provides the same
completions as MonoDevelop/SharpDevelop. The [server](https://github.com/nosami/OmniSharpServer) knows nothing about Vim, so could be plugged into most editors fairly easily. 
[Emacs](https://github.com/sp3ctum/omnisharp-emacs) and 
[Sublime Text 2](https://github.com/PaulCampbell/OmniSharpSublimePlugin) both have completion plugins utilising the OmniSharp server.

##Features

* Contextual code completion
	* Code documentation is displayed in the preview window when available (Xml Documentation for Windows, MonoDoc documentation for Mono)
	* CamelCase completions are supported, e.g Console.WL(TAB) will complete to Console.WriteLine
	* "Subsequence" completions are also supported. e.g. Console.Wline would also complete to Console.WriteLine
	* Completions are ranked in the following order
		* Exact start match (case sensitive)
		* Exact start match (case insensitive)
		* CamelCase completions
		* Subsequence match completions

* Jump to the definition of a type/variable/method
* Find types/symbols interactively (requires [CtrlP](https://github.com/kien/ctrlp.vim) plugin)
* Find implementations/derived types
* Find usages
* Contextual code actions (sort usings, use var....etc.) (requires [CtrlP](https://github.com/kien/ctrlp.vim) plugin)
    * Extract method
* Find and fix code issues (unused usings, use base type where possible....etc.) (requires [Syntastic](https://github.com/scrooloose/syntastic) plugin)
* Rename refactoring
* Semantic type highlighting
* Lookup type information of an type/variable/method
	* Can be printed to the status line or in the preview window
	* Displays documentation for an entity when using preview window
* Syntax error highlighting
* Integrated xbuild/msbuild (can run asynchronously if vim dispatch is installed)
* Code formatter
* Add currently edited file to the nearest project (currently will only add .cs files to a .csproj file)
```
	:OmniSharpAddToProject
```
* Add reference. Supports project and file reference. GAC referencing todo.
```
	:OmniSharpAddReference path_to_reference
```


##Screenshots
####Auto Complete
![OmniSharp screenshot](https://f.cloud.github.com/assets/667194/514371/dc03e2bc-be56-11e2-9745-c3202335e5ab.png)

####Find (and fix) Code Issues
![Code issues screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/codeissues.png)

####Find Types / Symbols
![Find Types screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/FindTypes.png)

####Find Usages
![Find Usages screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/FindUsages.png)

####Code Actions
![Code Actions screenshot](https://raw.github.com/nosami/Omnisharp/gh-pages/CodeActions.png)

##Installation

[pathogen.vim](https://github.com/tpope/vim-pathogen) is the recommended way to install OmniSharp.

####OSX / Linux
    cd ~/.vim/bundle
    git clone https://github.com/nosami/Omnisharp.git
    git submodule update --init
    cd Omnisharp/server
    xbuild /p:Platform="Any CPU"

####Windows
    c:\
    cd c:\Users\username\vimfiles\bundle
    git clone https://github.com/nosami/Omnisharp.git
    git submodule update --init
    cd Omnisharp\server
    msbuild /p:Platform="Any CPU"

###Install Python
Install [Python 2.7.5] (http://www.python.org/download/releases/2.7.5/). Make sure that you pick correct version of Python to match the architecture of Vim. 
For example, if you installed Vim using the default Windows installer, you will need to install the x86 (32 bit!) version of Python.

Verify that Python is working inside Vim with 

```vim
:echo has('python')
```

###(optional) Install vim-dispatch
The vim plugin [vim-dispatch] (https://github.com/tpope/vim-dispatch) is needed to make Omnisharp start the server automatically and for running asynchronous builds.
Use your favourite way to install it.

###(optional) Install syntastic
The vim plugin [syntastic] (https://github.com/scrooloose/syntastic) is needed for displaying code issues and syntax errors.
Use your favourite way to install it.

###(optional) Install ctrl-p
[CtrlP](https://github.com/kien/ctrlp.vim) is needed if you want to use the Code Actions, Find Type and Find Symbol features.

## How to use

By default, the server is started automatically if you have vim-dispatch installed when you open a .cs file.
It tries to detect your solution file (.sln) and starts the OmniSharp server passing the path to the solution file.

If you are using Tmux, the server will start in a new tmux session. In iterm2, a new tab is opened. Windows starts the server with a minimised cmd shell. For any other configuration, the server will start invisibly in the background. 


This behaviour can be disabled by setting `let g:Omnisharp_start_server = 0` in your vimrc.

When your close vim, and the omnisharp server is running, vim will ask you if you want to stop the OmniSharp server.
This behaviour can be disabled by setting `let g:Omnisharp_stop_server = 0` in your vimrc.

You can alternatively start the Omnisharp server manually:

	[mono] OmniSharp.exe -p (portnumber) -s (path\to\sln)

Add ``` -v Verbose``` to get extra information from the server.

OmniSharp listens to requests from Vim on port 2000 by default, so make sure that your firewall is configured to accept requests from localhost on this port.

To get completions, open one of the C# files from the solution within Vim and press Ctrl-X Ctrl-O in Insert mode 
(or just TAB if you have [SuperTab] (https://github.com/ervandew/supertab) installed). 
Repeat to cycle through completions, or use the cursor keys (eugh!)

If you prefer to get completions as you are typing, then you should take a look at [NeoComplete](https://github.com/Shougo/neocomplete.vim), [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)
or [NeoComplCache](https://github.com/Shougo/neocomplcache.vim). 


NeoComplCache is the easiest to set up as it is pure vimscript. However, it's no longer maintained. NeoComplete is the successor to NeoComplCache. It is faster than NeoComplCache but requires Vim to be compiled with +lua. (Windows users can find [vim compiled with +lua](http://tuxproject.de/projects/vim/) and [Lua 5.2](http://sourceforge.net/projects/luabinaries/files/5.2.1/Executables/) - place lua52.dll in the same folder as gvim.exe) 

YouCompleteMe is also fast, but is tricky to setup on Windows - trivial on linux or OSX.

[NeoComplete example settings](https://github.com/nosami/Omnisharp/wiki/Example-NeoComplete-Settings)

[NeoComplCache example settings](https://github.com/nosami/Omnisharp/wiki/Example-NeoComplCache-Settings)

Simple syntax error highlighting is automatically performed when saving the current buffer.

To use the other features, you'll want to create key bindings for them. See the example vimrc for more info.

##Configuration

### Example vimrc

```vim
" OmniSharp won't work without this setting
filetype plugin on

"This is the default value, setting it isn't actually necessary
let g:OmniSharp_host = "http://localhost:2000"

"Set the type lookup function to use the preview window instead of the status line
"let g:OmniSharp_typeLookupInPreview = 1

"Timeout in seconds to wait for a response from the server
let g:OmniSharp_timeout = 1

"Showmatch significantly slows down omnicomplete
"when the first match contains parentheses.
set noshowmatch
"Set autocomplete function to OmniSharp (if not using YouCompleteMe completion plugin)
autocmd FileType cs setlocal omnifunc=OmniSharp#Complete

"Super tab settings
"let g:SuperTabDefaultCompletionType = 'context'
"let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
"let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
"let g:SuperTabClosePreviewOnPopupClose = 1

"don't autoselect first item in omnicomplete, show if only one item (for preview)
"remove preview if you don't want to see any documentation whatsoever.
set completeopt=longest,menuone,preview
" Fetch full documentation during omnicomplete requests. 
" There is a performance penalty with this (especially on Mono)
" By default, only Type/Method signatures are fetched. Full documentation can still be fetched when
" you need it with the :OmniSharpDocumentation command.
" let g:omnicomplete_fetch_documentation=1

"Move the preview window (code documentation) to the bottom of the screen, so it doesn't move the code!
"You might also want to look at the echodoc plugin
set splitbelow

" Synchronous build (blocks Vim)
"autocmd FileType cs nnoremap <F5> :wa!<cr>:OmniSharpBuild<cr>
" Builds can also run asynchronously with vim-dispatch installed
autocmd FileType cs nnoremap <F5> :wa!<cr>:OmniSharpBuildAsync<cr>

"The following commands are contextual, based on the current cursor position.

autocmd FileType cs nnoremap gd :OmniSharpGotoDefinition<cr>
nnoremap <leader>fi :OmniSharpFindImplementations<cr>
nnoremap <leader>ft :OmniSharpFindType<cr>
nnoremap <leader>fs :OmniSharpFindSymbol<cr>
nnoremap <leader>fu :OmniSharpFindUsages<cr>
nnoremap <leader>fm :OmniSharpFindMembersInBuffer<cr>
" cursor can be anywhere on the line containing an issue for this one
nnoremap <leader>x  :OmniSharpFixIssue<cr>
nnoremap <leader>tt :OmniSharpTypeLookup<cr>
nnoremap <leader>dc :OmniSharpDocumentation<cr>

" Get Code Issues and syntax errors
let g:syntastic_cs_checkers = ['syntax', 'issues']
autocmd BufEnter,TextChanged,InsertLeave *.cs SyntasticCheck

"show type information automatically when the cursor stops moving
autocmd CursorHold *.cs call OmniSharp#TypeLookupWithoutDocumentation()
" this setting controls how long to pause (in ms) before fetching type / symbol information.
set updatetime=500
" Remove 'Press Enter to continue' message when type information is longer than one line.
set cmdheight=2

" Contextual code actions (requires CtrlP)
nnoremap <leader><space> :OmniSharpGetCodeActions<cr>
" Run code actions with text selected in visual mode to extract method
vnoremap <leader><space> :call OmniSharp#GetCodeActions('visual')<cr>

" rename with dialog
nnoremap <leader>nm :OmniSharpRename<cr>
nnoremap <F2> :OmniSharpRename<cr>      
" rename without dialog - with cursor on the symbol to rename... ':Rename newname'
command! -nargs=1 Rename :call OmniSharp#RenameTo("<args>")

" Force OmniSharp to reload the solution. Useful when switching branches etc.
nnoremap <leader>rl :OmniSharpReloadSolution<cr>
nnoremap <leader>cf :OmniSharpCodeFormat<cr>
" Load the current .cs file to the nearest project
nnoremap <leader>tp :OmniSharpAddToProject<cr>
" Automatically add new cs files to the nearest project on save
autocmd BufWritePost *.cs call OmniSharp#AddToProject()
" (Experimental - uses vim-dispatch or vimproc plugin) - Start the omnisharp server for the current solution
nnoremap <leader>ss :OmniSharpStartServer<cr>
nnoremap <leader>sp :OmniSharpStopServer<cr>

" Add syntax highlighting for types and interfaces
nnoremap <leader>th :OmniSharpHighlightTypes<cr>
"Don't ask to save when changing buffers (i.e. when jumping to a type definition)
set hidden
```


#####TODO

- Extract method
- Move type to own file
- Unite plugin for find types / symbols

Pull requests welcome!


