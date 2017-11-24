![OmniSharp](logo.png)

# OmniSharp

OmniSharp-vim is a plugin for Vim to provide IDE like abilities for C#. A list of currently implemented features is provided below.

OmniSharp works both on Windows and on Linux and OS X with Mono.

The plugin uses the [OmniSharp server](https://github.com/OmniSharp/omnisharp-server) which is a thin wrapper around the awesome [NRefactory](https://github.com/icsharpcode/NRefactory) library, and it provides the same completions as MonoDevelop and SharpDevelop. 

The server knows nothing about Vim, so could be plugged into most editors fairly easily.
[Emacs](https://github.com/OmniSharp/omnisharp-emacs),
[Sublime Text 2](https://github.com/PaulCampbell/OmniSharpSublimePlugin) and [Sublime Text 3](https://github.com/OmniSharp/omnisharp-sublime) all have completion plugins utilising the OmniSharp server.

Omnisharp-vim can now be run with the [omnisharp-roslyn server](https://github.com/OmniSharp/omnisharp-roslyn) as an alternative to the Omnisharp Server.

## Features

* Contextual code completion
  * Code documentation is displayed in the preview window when available (Xml Documentation for Windows, MonoDoc documentation for Mono)
  * CamelCase completions are supported, e.g Console.WL(TAB) will complete to Console.WriteLine
  * "Subsequence" completions are also supported. e.g. Console.Wline would also complete to Console.WriteLine
  * Completions are ranked in the following order
    * Exact start match (case sensitive)
    * Exact start match (case insensitive)
    * CamelCase completions
    * Subsequence match completions
  * Completion snippets are supported. e.g. Console.WriteLine(TAB) (ENTER) will complete to Console.WriteLine(string value) and expand a dynamic snippet, this will place you in SELECT mode and the first method argument will be selected. 
    * Requires [UltiSnips](https://github.com/SirVer/ultisnips) and supports standard C-x C-o completion, [Supertab](https://github.com/ervandew/supertab) and [Neocomplete](https://github.com/Shougo/neocomplete.vim).
    * Requires `set completeopt-=preview` when using [Neocomplete](https://github.com/Shougo/neocomplete.vim) because of a compatibility issue with [UltiSnips](https://github.com/SirVer/ultisnips). 
    * This functionality requires a recent version of Vim, you can check if your version is supported by running `:echo has("patch-7.3-598")`, it should output 1.

* Jump to the definition of a type/variable/method
* Find types/symbols interactively (requires [CtrlP](https://github.com/ctrlpvim/ctrlp.vim) plugin or [unite.vim](https://github.com/Shougo/unite.vim) plugin)
* Find implementations/derived types
* Find usages
* Contextual code actions (sort usings, use var....etc.) (requires [CtrlP](https://github.com/ctrlpvim/ctrlp.vim) plugin or [unite.vim](https://github.com/Shougo/unite.vim) plugin)
  * Extract method
* Find and fix code issues (unused usings, use base type where possible....etc.) (requires [Syntastic](https://github.com/scrooloose/syntastic) plugin)
* Fix using statements for the current buffer (sort, remove and add any missing using statements where possible)
* Rename refactoring
* Semantic type highlighting
* Lookup type information of an type/variable/method
  * Can be printed to the status line or in the preview window
  * Displays documentation for an entity when using preview window
* Syntax error highlighting
* On the fly semantic error highlighting (nearly as good as a full compilation!)
* Integrated xbuild/msbuild (can run asynchronously if supported)
* Code formatter
* Automatic folding of `# region` and `<summary></summary>` (make sure to have `set foldmethod=syntax`)
* Add currently edited file to the nearest project (currently will only add .cs files to a .csproj file)

```vim
:OmniSharpAddToProject
```

* Add reference. Supports project and file reference. GAC referencing todo.

```vim
:OmniSharpAddReference path_to_reference
```

* [Test runner](https://github.com/OmniSharp/omnisharp-vim/wiki/Test-Runner)

## Screenshots
#### Auto Complete
![OmniSharp screenshot](https://f.cloud.github.com/assets/667194/514371/dc03e2bc-be56-11e2-9745-c3202335e5ab.png)

#### Find (and fix) Code Issues
![Code issues screenshot](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/codeissues.png)

#### Find Types / Symbols
![Find Types screenshot](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/FindTypes.png)

#### Find Usages
![Find Usages screenshot](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/FindUsages.png)

#### Code Actions
![Code Actions screenshot](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/CodeActions.png)

## Installation

[pathogen.vim](https://github.com/tpope/vim-pathogen) is the recommended way to install OmniSharp.

For [Vundle](https://github.com/VundleVim/Vundle.vim):

```vim
Plugin 'OmniSharp/omnisharp-vim'
```

You'll still need to build the server using `xbuild` or `msbuild` as below.

#### OSX / Linux

Requires a minimum of Mono 3.0.12 - If you absolutely must use mono 2.10 then checkout the mono-2.10.8 tag. [Updating mono on ubuntu](https://github.com/OmniSharp/omnisharp-server/wiki)

```sh
cd ~/.vim/bundle
git clone https://github.com/OmniSharp/omnisharp-vim.git
cd omnisharp-vim
git submodule update --init --recursive
cd server
xbuild
```

Note that if you have Mono installed outside of the ["standard" paths](https://github.com/OmniSharp/omnisharp-server/blob/master/OmniSharp/Solution/AssemblySearch.cs#L35-L52) (for example, if it is installed via Boxen where your homebrew root is not `/usr/local/`, you'll need to either add the path to the `AssemblySearch.cs` before building, or symlink your installation to one of the standard paths.

If you are planning to use OmniSharp-Roslyn, run the following commands:
```sh
cd ~/.vim/bundle/omnisharp-vim/omnisharp-roslyn
./build.sh
```

#### Windows

```dosbatch
c:\
cd c:\Users\<username>\vimfiles\bundle
git clone https://github.com/OmniSharp/omnisharp-vim.git
cd omnisharp-vim
git submodule update --init --recursive
cd server
msbuild
```

If you are planning to use OmniSharp-Roslyn, run the following commands in `PowerShell`:
```sh
cd c:\Users\<username>\vimfiles\bundle\omnisharp-vim\omnisharp-roslyn
./build.ps1
```

### Install Python
Install last version of 2.7 series ([Python 2.7.8](https://www.python.org/download/releases/2.7.8/) at the time of this writing). Make sure that you pick correct version of Python to match the architecture of Vim.
For example, if you installed Vim using the default Windows installer, you will need to install the x86 (32 bit!) version of Python.

Verify that Python is working inside Vim with

```vim
:echo has('python')
```

### Asynchronous command execution

Omnisharp-vim plugin can start the server and run asynchronous builds only if any of the following criteria is met:

* Vim with job control API is used (8.0+)
* [neovim](https://neovim.io) with job control API is used
* [vim-dispatch](https://github.com/tpope/vim-dispatch) is installed
* [vimproc.vim](https://github.com/Shougo/vimproc.vim) is installed

#### (optional) Install vim-dispatch
The vim plugin [vim-dispatch](https://github.com/tpope/vim-dispatch) is needed to make OmniSharp start the server automatically and for running asynchronous builds.
Use your favourite way to install it.

### (optional) Install syntastic
The vim plugin [syntastic](https://github.com/scrooloose/syntastic) is needed for displaying code issues and syntax errors.
Use your favourite way to install it.

### (optional) Install ctrlp.vim, unite.vim or fzf.vim

If you want to use the Code Actions, Find Type and Find Symbol features, you will need to install one of the following plugins:

- [CtrlP](https://github.com/ctrlpvim/ctrlp.vim)
- [unite.vim](https://github.com/Shougo/unite.vim)
- [fzf.vim](https://github.com/junegunn/fzf.vim)

If you have installed more than one, you can choose one by `g:OmniSharp_selector_ui` variable.

```vim
let g:OmniSharp_selector_ui = 'unite'  " Use unite.vim
let g:OmniSharp_selector_ui = 'ctrlp'  " Use ctrlp.vim
let g:OmniSharp_selector_ui = 'fzf'    " Use fzf.vim
```

## How to use

By default, the server is started automatically if you have vim-dispatch installed when you open a .cs file.
It tries to detect your solution file (.sln) and starts the OmniSharp server passing the path to the solution file.

If you are using Tmux, the server will start in a new tmux session. In iterm2, a new tab is opened. Windows starts the server with a minimised cmd shell. For any other configuration, the server will start invisibly in the background.


This behaviour can be disabled by setting `let g:Omnisharp_start_server = 0` in your vimrc.

When your close vim, and the OmniSharp server is running, vim will ask you if you want to stop the OmniSharp server.
This behaviour can be disabled by setting `let g:Omnisharp_stop_server = 0` in your vimrc.

In addition you can tweak some OmniSharp server behaviour by changing the global configuration file placed:

#### OSX / Linux

```sh
~/.vim/bundle/omnisharp-vim/server/config.json
```

#### Windows

```dosbatch
c:\Users\<username>\vimfiles\bundle\omnisharp-vim\server\config.json
```

Or by providing a local version, that by default called `omnisharp.json` and placed in the same solution directory.
If you want use another configuration file name, you should set `let g:Omnisharp_server_config_name = '<your file name>.json'` variable in the vimrc.

Alternatively, you can start the OmniSharp server manually:

```
[mono] OmniSharp.exe -p (portnumber) -s (path\to\sln)
```

Add `-config (path\to\json) Configuration` to provide a server configuration file.
Add `-v Verbose` to get extra information from the server.

OmniSharp listens to requests from Vim on port 2000 by default, so make sure that your firewall is configured to accept requests from localhost on this port.

To get completions, open one of the C# files from the solution within Vim and press `<C-x><C-o>` (that is ctrl x followed by ctrl o) in Insert mode
(or just TAB if you have [SuperTab](https://github.com/ervandew/supertab) installed).
Repeat to cycle through completions, or use the cursor keys (eugh!)

If you prefer to get completions as you are typing, then you should take a look at [NeoComplete](https://github.com/Shougo/neocomplete.vim), [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)
or [NeoComplCache](https://github.com/Shougo/neocomplcache.vim).


NeoComplCache is the easiest to set up as it is pure vimscript. However, it's no longer maintained. NeoComplete is the successor to NeoComplCache. It is faster than NeoComplCache but requires Vim to be compiled with +lua. (Windows users can find [vim compiled with +lua](https://tuxproject.de/projects/vim/) and [Lua 5.2](http://sourceforge.net/projects/luabinaries/files/5.2.1/Executables/) - place lua52.dll in the same folder as gvim.exe) . OSX users can `brew install vim --HEAD --with-lua`

YouCompleteMe is also fast, but is tricky to setup on Windows - trivial on linux or OSX.

[NeoComplete example settings](https://github.com/OmniSharp/omnisharp-vim/wiki/Example-NeoComplete-Settings)

[NeoComplCache example settings](https://github.com/OmniSharp/omnisharp-vim/wiki/Example-NeoComplCache-Settings)

Simple syntax error highlighting is automatically performed when saving the current buffer or leaving insert mode.

To use the other features, you'll want to create key bindings for them. See the example vimrc below for more info.

### Using with omnisharp-roslyn

OmniSharp-vim can now be run with [omnisharp-roslyn](https://github.com/OmniSharp/omnisharp-roslyn) instead of the OmniSharp server.
To switch, write one of the below lines to your vimrc.

```
let g:OmniSharp_server_type = 'v1'
let g:OmniSharp_server_type = 'roslyn'
```

### Other useful tools

- [grunt-init-csharpsolution](https://github.com/nosami/grunt-init-csharpsolution) Useful for quickly creating a C# solution with a couple of projects. Easily adaptable.
![screenshot](https://raw.githubusercontent.com/nosami/nosami.github.io/master/grunt-init-csharpsolution.gif)
- [WarmUp](https://github.com/chucknorris/warmup/issues) Same as above, but it didn't work for me on OSX when I tried.
- [OpenIDE](https://github.com/continuoustests/OpenIDE) Lots of uses. I use it for creating new project files and generating classes with the namespace and class pre-populated. It's very extensible.
- [OrangeT/vim-csharp](https://github.com/OrangeT/vim-csharp) Advanced syntax highlighting including razor support. Contains snippets for Razor, Xunit and Moq.
- [devtools-terminal](http://blog.dfilimonov.com/2013/09/12/devtools-terminal.html) Embed OmniSharp inside Chrome
![dev-tools screenshot](https://raw.githubusercontent.com/nosami/nosami.github.io/master/aspvnext.gif)

## Configuration

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

"Super tab settings - uncomment the next 4 lines
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
" let g:omnicomplete_fetch_full_documentation=1

"Move the preview window (code documentation) to the bottom of the screen, so it doesn't move the code!
"You might also want to look at the echodoc plugin
set splitbelow

" Get Code Issues and syntax errors
let g:syntastic_cs_checkers = ['syntax', 'semantic', 'issues']
" If you are using the omnisharp-roslyn backend, use the following
" let g:syntastic_cs_checkers = ['code_checker']
augroup omnisharp_commands
    autocmd!

    "Set autocomplete function to OmniSharp (if not using YouCompleteMe completion plugin)
    autocmd FileType cs setlocal omnifunc=OmniSharp#Complete

    " Synchronous build (blocks Vim)
    "autocmd FileType cs nnoremap <F5> :wa!<cr>:OmniSharpBuild<cr>
    " Builds can also run asynchronously with vim-dispatch installed
    autocmd FileType cs nnoremap <leader>b :wa!<cr>:OmniSharpBuildAsync<cr>
    " automatic syntax check on events (TextChanged requires Vim 7.4)
    autocmd BufEnter,TextChanged,InsertLeave *.cs SyntasticCheck

    " Automatically add new cs files to the nearest project on save
    autocmd BufWritePost *.cs call OmniSharp#AddToProject()

    "show type information automatically when the cursor stops moving
    autocmd CursorHold *.cs call OmniSharp#TypeLookupWithoutDocumentation()

    "The following commands are contextual, based on the current cursor position.

    autocmd FileType cs nnoremap gd :OmniSharpGotoDefinition<cr>
    autocmd FileType cs nnoremap <leader>fi :OmniSharpFindImplementations<cr>
    autocmd FileType cs nnoremap <leader>ft :OmniSharpFindType<cr>
    autocmd FileType cs nnoremap <leader>fs :OmniSharpFindSymbol<cr>
    autocmd FileType cs nnoremap <leader>fu :OmniSharpFindUsages<cr>
    "finds members in the current buffer
    autocmd FileType cs nnoremap <leader>fm :OmniSharpFindMembers<cr>
    " cursor can be anywhere on the line containing an issue
    autocmd FileType cs nnoremap <leader>x  :OmniSharpFixIssue<cr>
    autocmd FileType cs nnoremap <leader>fx :OmniSharpFixUsings<cr>
    autocmd FileType cs nnoremap <leader>tt :OmniSharpTypeLookup<cr>
    autocmd FileType cs nnoremap <leader>dc :OmniSharpDocumentation<cr>
    "navigate up by method/property/field
    autocmd FileType cs nnoremap <C-K> :OmniSharpNavigateUp<cr>
    "navigate down by method/property/field
    autocmd FileType cs nnoremap <C-J> :OmniSharpNavigateDown<cr>

augroup END


" this setting controls how long to wait (in ms) before fetching type / symbol information.
set updatetime=500
" Remove 'Press Enter to continue' message when type information is longer than one line.
set cmdheight=2

" Contextual code actions (requires CtrlP or unite.vim)
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

" Start the omnisharp server for the current solution
nnoremap <leader>ss :OmniSharpStartServer<cr>
nnoremap <leader>sp :OmniSharpStopServer<cr>

" Add syntax highlighting for types and interfaces
nnoremap <leader>th :OmniSharpHighlightTypes<cr>
"Don't ask to save when changing buffers (i.e. when jumping to a type definition)
set hidden

" Enable snippet completion, requires completeopt-=preview
let g:OmniSharp_want_snippet=1
```


##### TODO

- Move type to own file

Pull requests welcome!


