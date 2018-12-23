![OmniSharp](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/logo-OmniSharp.png)

![Travis status](https://api.travis-ci.org/OmniSharp/omnisharp-vim.svg?branch=master)
![AppVeyor status](https://ci.appveyor.com/api/projects/status/32r7s2skrgm9ubva?svg=true)

# OmniSharp

OmniSharp-vim is a plugin for Vim to provide IDE like abilities for C#.

OmniSharp works on Windows, and on Linux and OS X with Mono.

The plugin relies on the [OmniSharp-Roslyn](https://github.com/OmniSharp/omnisharp-roslyn) server, a .NET development platform used by several editors including Visual Studio Code, Emacs, Atom and others.

## Features

* Contextual code completion
  * Code documentation is displayed in the preview window when available (Xml Documentation for Windows, MonoDoc documentation for Mono)
  * Completion snippets are supported. e.g. Console.WriteLine(TAB) (ENTER) will complete to Console.WriteLine(string value) and expand a dynamic snippet, this will place you in SELECT mode and the first method argument will be selected. 
    * Requires [UltiSnips](https://github.com/SirVer/ultisnips) and supports standard C-x C-o completion as well as completion/autocompletion plugins such as [asyncomplete-vim](https://github.com/prabirshrestha/asyncomplete.vim), [Supertab](https://github.com/ervandew/supertab), [Neocomplete](https://github.com/Shougo/neocomplete.vim) etc.
    * Requires `set completeopt-=preview` when using [Neocomplete](https://github.com/Shougo/neocomplete.vim) because of a compatibility issue with [UltiSnips](https://github.com/SirVer/ultisnips). 

* Jump to the definition of a type/variable/method
* Find symbols interactively (can use plugin: [fzf.vim](https://github.com/junegunn/fzf.vim), [CtrlP](https://github.com/ctrlpvim/ctrlp.vim) or [unite.vim](https://github.com/Shougo/unite.vim))
* Find implementations/derived types
* Find usages
* Contextual code actions (unused usings, use var....etc.) (can use plugin: [fzf.vim](https://github.com/junegunn/fzf.vim), [CtrlP](https://github.com/ctrlpvim/ctrlp.vim) or [unite.vim](https://github.com/Shougo/unite.vim))
* Find code issues (unused usings, use base type where possible....etc.) (requires plugin: [ALE](https://github.com/w0rp/ale) or [Syntastic](https://github.com/vim-syntastic/syntastic))
* Fix using statements for the current buffer (sort, remove and add any missing using statements where possible)
* Rename refactoring
* Semantic type highlighting
* Lookup type information of an type/variable/method
  * Can be printed to the status line or in the preview window
  * Displays documentation for an entity when using preview window
* Code error checking
* Code formatter

## Screenshots
#### Auto Complete
![OmniSharp screenshot](https://f.cloud.github.com/assets/667194/514371/dc03e2bc-be56-11e2-9745-c3202335e5ab.png)

#### Find Symbols
![Find Symbols screenshot](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/FindTypes.png)

#### Find Usages
![Find Usages screenshot](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/FindUsages.png)

#### Code Actions
![Code Actions screenshot](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/CodeActions.png)

#### Code Actions Available (see [wiki](https://github.com/OmniSharp/omnisharp-vim/wiki/Code-Actions-Available-flag) for details)
![Code Actions Available](https://user-images.githubusercontent.com/5274565/38906320-1aa2d7c0-430a-11e8-9ee3-40790b7e600e.png)

## Installation
### Plugin
Install the vim plugin using your preferred plugin manager:

| Plugin Manager                                       | Command                                                                              |
|------------------------------------------------------|--------------------------------------------------------------------------------------|
| [Vim-plug](https://github.com/junegunn/vim-plug)     | `Plug 'OmniSharp/omnisharp-vim'`                                                     |
| [Vundle](https://github.com/gmarik/vundle)           | `Bundle 'OmniSharp/omnisharp-vim'`                                                   |
| [NeoBundle](https://github.com/Shougo/neobundle.vim) | `NeoBundle 'OmniSharp/omnisharp-vim'`                                                |
| [Pathogen](https://github.com/tpope/vim-pathogen)    | `git clone git://github.com/OmniSharp/omnisharp-vim.git ~/.vim/bundle/omnisharp-vim` |

### Server
OmniSharp-vim depends on the [OmniSharp-Roslyn](https://github.com/OmniSharp/omnisharp-roslyn) server. The first time OmniSharp-vim tries to open a C# file, it will check for the presence of the server, and if not found it will ask if it should be downloaded. Answer 'y' and the latest version will be downloaded and extracted to `~/.omnisharp/omnisharp-roslyn`, ready to use. *Note:* Requires [`curl`](https://curl.haxx.se/) or [`wget`](https://www.gnu.org/software/wget/) on Linux, macOS, Cygwin and WSL.

**NOTE:** The latest versions of the HTTP OmniSharp-Roslyn server are not accepting HTTP connections on Linux/Mac systems - see [OmniSharp-Roslyn#1274](https://github.com/OmniSharp/omnisharp-roslyn/issues/1274). Until this is resolved, OmniSharp-vim installs the latest working version of OmniSharp-Roslyn, `1.32.1`. To override this behaviour and install a particular release, use the `:OmniSharpInstall` command like this:

```vim
:OmniSharpInstall 'v1.32.5'
```

#### Manual installation
To install the server manually, follow these steps:

Download the latest **HTTP** release for your platform from the [releases](https://github.com/OmniSharp/omnisharp-roslyn/releases) page. OmniSharp-vim uses http to communicate with the server, so select the **HTTP** variant for your architecture. This means that for a 64-bit Windows system, the `omnisharp.http-win-x64.zip` package should be downloaded, whereas Mac users should select `omnisharp.http-osx.tar.gz` etc.

Extract the binaries and configure your vimrc with the path to the `OmniSharp.exe` file, e.g.:

```vim
let g:OmniSharp_server_path = 'C:\OmniSharp\omnisharp.http-win-x64\OmniSharp.exe'
```
```vim
let g:OmniSharp_server_path = '/home/me/omnisharp/omnisharp.http-linux-x64/omnisharp/OmniSharp.exe'
```

#### Windows: Cygwin
No special configuration is required for cygwin. The automatic installation script for cygwin downloads the *Windows* OmniSharp-roslyn release. OmniSharp-vim detects that it is running in a cygwin environment and automatically enables Windows/cygwin file path translations by setting the default value of `g:OmniSharp_translate_cygwin_wsl` to `1`.

#### Windows Subsystem for Linux (WSL)
OmniSharp-roslyn can function perfectly well in WSL using linux binaries, if the environment is correctly configured (see [OmniSharp-roslyn](https://github.com/OmniSharp/omnisharp-roslyn) for requirements).
However, if you have the .NET Framework installed in Windows, you may have better results using the Windows binaries. To do this, follow the Manual installation instructions above, configure your vimrc to point to the `OmniSharp.exe` file, and let OmniSharp-vim know that you are operating in Cygwin/WSL mode (indicating that file paths need to be translated by OmniSharp-vim from Unix-Windows and back:

```vim
let g:OmniSharp_server_path = '/mnt/c/OmniSharp/omnisharp.http-win-x64/OmniSharp.exe'
let g:OmniSharp_translate_cygwin_wsl = 1
```

#### Linux and Mac
OmniSharp-Roslyn requires Mono on Linux and OSX. The roslyn server [releases](https://github.com/OmniSharp/omnisharp-roslyn/releases) usually come with an embedded Mono, but this can be overridden to use the installed Mono by setting `g:OmniSharp_server_use_mono` in your vimrc. See [The Mono Project](https://www.mono-project.com/download/stable/) for installation details.

```vim
    let g:OmniSharp_server_use_mono = 1
```

##### libuv
OmniSharp-Roslyn also requires [libuv](http://libuv.org/) on Linux and Mac. This is typically a simple install step, e.g. `brew install libuv` on Mac, `apt-get install libuv1-dev` on debian/Ubuntu, `pacman -S libuv` on arch linux, `dnf install libuv libuv-devel` on Fedora/CentOS, etc.

Please note that if your distro has a "dev" package (`libuv1-dev`, `libuv-devel` etc.) then you will probably need it.

### Install Python
Install the latest version of python 3 ([Python 3.7](https://www.python.org/downloads/release/python-370/)) or 2 ([Python 2.7.15](https://www.python.org/downloads/release/python-2715/)).
Make sure that you pick correct version of Python to match your vim's architecture (32-bit python for 32-bit vim, 64-bit python for 64-bit vim).

Verify that Python is working inside Vim with

```vim
:echo has('python3') || has('python')
```

### Asynchronous command execution
OmniSharp-vim can start the server only if any of the following criteria is met:

* Vim with job control API is used (8.0+)
* [neovim](https://neovim.io) with job control API is used
* [vim-dispatch](https://github.com/tpope/vim-dispatch) is installed
* [vimproc.vim](https://github.com/Shougo/vimproc.vim) is installed

### (optional) Install ALE

If [ALE](https://github.com/w0rp/ale) is installed, it will automatically be used to asynchronously check your code for errors.

No further configuration is necessary. However, be aware that ALE supports multiple C# linters, and will run all linters that are available on your system. To limit ALE to only use OmniSharp (recommended), add this to your .vimrc:

```vim
let g:ale_linters = {
\ 'cs': ['OmniSharp']
\}
```

### (optional) Install syntastic
The vim plugin [syntastic](https://github.com/vim-syntastic/syntastic) can be used if you don't have ALE.
Configure it to work with OmniSharp with the following line in your vimrc.

```vim
let g:syntastic_cs_checkers = ['code_checker']
```

### (optional) Install ctrlp.vim, unite.vim or fzf.vim
If one of these plugins is detected, it will be used as the selector for Code Actions and Find Symbols features:

- [fzf.vim](https://github.com/junegunn/fzf.vim)
- [CtrlP](https://github.com/ctrlpvim/ctrlp.vim)
- [unite.vim](https://github.com/Shougo/unite.vim)

If you have installed more than one, or you prefer to use native vim functionality (command line, quickfix window etc.) rather than a selector plugin, you can choose an option with the `g:OmniSharp_selector_ui` variable.

```vim
let g:OmniSharp_selector_ui = 'unite'  " Use unite.vim
let g:OmniSharp_selector_ui = 'ctrlp'  " Use ctrlp.vim
let g:OmniSharp_selector_ui = 'fzf'    " Use fzf.vim
let g:OmniSharp_selector_ui = ''       " Use vim - command line, quickfix etc.
```

## How to use
By default, the server is started automatically when you open a .cs file.
It tries to detect your solution file (.sln) and starts the OmniSharp-roslyn server, passing the path to the solution file.

In vim8 and neovim, the server is started invisibly by a vim job.
In older versions of vim, the server will be started in different ways depending on whether you are using vim-dispatch in tmux, or are using vim-proc, gvim or running vim in a terminal.

This behaviour can be disabled by setting `let g:OmniSharp_start_server = 0` in your vimrc. You can then start the server manually from within vim with `:OmniSharpStartServer`. Alternatively, the server can be manually started from outside vim:

```sh
[mono] OmniSharp.exe -p (portnumber) -s (path/to/sln)
```

Add `-v` to get extra information from the server.

When vim starts an OmniSharp server, it will bind to a random port by default. If you need to run servers on specific ports (or you are running manually, as above) you can use `let g:OmniSharp_server_ports = {'C:\path\to\project.sln': 2000, 'C:\path\to\other\project': 2001}` to map solution files and/or project directories to specific ports, or you can `let g:OmniSharp_port = 2000` to always use a single port (though this will prevent you from running OmniSharp servers on multiple projects).

To get completions, open a C# file from your solution within Vim and press `<C-x><C-o>` (that is ctrl x followed by ctrl o) in Insert mode, or use a completion or autocompletion plugin.

To use the other features, you'll want to create key bindings for them. See the example vimrc below for more info.

See the [wiki](https://github.com/OmniSharp/omnisharp-vim/wiki) for more custom configuration examples.

## Configuration

### Example vimrc

```vim
" OmniSharp won't work without this setting
filetype plugin on

" Set the type lookup function to use the preview window instead of echoing it
"let g:OmniSharp_typeLookupInPreview = 1

" Timeout in seconds to wait for a response from the server
let g:OmniSharp_timeout = 5

" Don't autoselect first omnicomplete option, show options even if there is only
" one (so the preview documentation is accessible). Remove 'preview' if you
" don't want to see any documentation whatsoever.
set completeopt=longest,menuone,preview

" Fetch full documentation during omnicomplete requests.
" There is a performance penalty with this (especially on Mono).
" By default, only Type/Method signatures are fetched. Full documentation can
" still be fetched when you need it with the :OmniSharpDocumentation command.
"let g:omnicomplete_fetch_full_documentation = 1

" Set desired preview window height for viewing documentation.
" You might also want to look at the echodoc plugin.
set previewheight=5

" Tell ALE to use OmniSharp for linting C# files, and no other linters.
let g:ale_linters = { 'cs': ['OmniSharp'] }

" Fetch semantic type/interface/identifier names on BufEnter and highlight them
let g:OmniSharp_highlight_types = 1

augroup omnisharp_commands
    autocmd!

    " When Syntastic is available but not ALE, automatic syntax check on events
    " (TextChanged requires Vim 7.4)
    " autocmd BufEnter,TextChanged,InsertLeave *.cs SyntasticCheck

    " Show type information automatically when the cursor stops moving
    autocmd CursorHold *.cs call OmniSharp#TypeLookupWithoutDocumentation()

    " Update the highlighting whenever leaving insert mode
    autocmd InsertLeave *.cs call OmniSharp#HighlightBuffer()

    " Alternatively, use a mapping to refresh highlighting for the current buffer
    autocmd FileType cs nnoremap <buffer> <Leader>th :OmniSharpHighlightTypes<CR>

    " The following commands are contextual, based on the cursor position.
    autocmd FileType cs nnoremap <buffer> gd :OmniSharpGotoDefinition<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>fi :OmniSharpFindImplementations<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>fs :OmniSharpFindSymbol<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>fu :OmniSharpFindUsages<CR>

    " Finds members in the current buffer
    autocmd FileType cs nnoremap <buffer> <Leader>fm :OmniSharpFindMembers<CR>

    autocmd FileType cs nnoremap <buffer> <Leader>fx :OmniSharpFixUsings<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>tt :OmniSharpTypeLookup<CR>
    autocmd FileType cs nnoremap <buffer> <Leader>dc :OmniSharpDocumentation<CR>
    autocmd FileType cs nnoremap <buffer> <C-\> :OmniSharpSignatureHelp<CR>
    autocmd FileType cs inoremap <buffer> <C-\> <C-o>:OmniSharpSignatureHelp<CR>

    " Navigate up and down by method/property/field
    autocmd FileType cs nnoremap <buffer> <C-k> :OmniSharpNavigateUp<CR>
    autocmd FileType cs nnoremap <buffer> <C-j> :OmniSharpNavigateDown<CR>
augroup END

" Contextual code actions (uses fzf, CtrlP or unite.vim when available)
nnoremap <Leader><Space> :OmniSharpGetCodeActions<CR>
" Run code actions with text selected in visual mode to extract method
xnoremap <Leader><Space> :call OmniSharp#GetCodeActions('visual')<CR>

" Rename with dialog
nnoremap <Leader>nm :OmniSharpRename<CR>
nnoremap <F2> :OmniSharpRename<CR>
" Rename without dialog - with cursor on the symbol to rename: `:Rename newname`
command! -nargs=1 Rename :call OmniSharp#RenameTo("<args>")

nnoremap <Leader>cf :OmniSharpCodeFormat<CR>

" Start the omnisharp server for the current solution
nnoremap <Leader>ss :OmniSharpStartServer<CR>
nnoremap <Leader>sp :OmniSharpStopServer<CR>

" Enable snippet completion
" let g:OmniSharp_want_snippet=1
```

Pull requests welcome!
