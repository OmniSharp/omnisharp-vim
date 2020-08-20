<h1 align="center">
  <img alt="OmniSharp" src="https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/omnisharp-logo-light.png">
</h1>

[![Travis status](https://api.travis-ci.org/OmniSharp/omnisharp-vim.svg)](https://travis-ci.org/OmniSharp/omnisharp-vim)
[![AppVeyor status](https://ci.appveyor.com/api/projects/status/github/OmniSharp/omnisharp-vim?svg=true)](https://ci.appveyor.com/project/nickspoons/omnisharp-vim)

OmniSharp-vim is a plugin for Vim to provide IDE like abilities for C#.

OmniSharp works on Windows, and on Linux and OS X with Mono.

The plugin relies on the [OmniSharp-Roslyn](https://github.com/OmniSharp/omnisharp-roslyn) server, a .NET development platform used by several editors including Visual Studio Code, Emacs, Atom and others.

## New! Popups

Use Vim's popup windows and neovim's floating windows to display code/documentation without disrupting your window layouts: see [Popups](#popups) section for details and configuration options.

![Popup Demo](https://raw.github.com/OmniSharp/omnisharp-vim/gh-pages/omnisharp-popup-demo.gif)

## New! Run unit tests

It is now possible to run unit tests via OmniSharp-roslyn, with success/failures listed in the quickfix window for easy navigation:

```vim
" Run the current unit test (the cursor should be on/inside the test method)
:OmniSharpRunTest

" Run all unit tests in the current file
:OmniSharpRunTestsInFile

" Run all unit tests in the current file, and file `tests/test1.cs`
:OmniSharpRunTestsInFile % tests/test1.cs
```

**Note:** this is only available using the stdio server, and unfortunately does _not_ work in translated WSL, due to the way OmniSharp-roslyn runs the tests.

## Asynchronous server interactions over stdio

For vim8 and neovim, OmniSharp-vim uses the OmniSharp-roslyn stdio server instead of the older HTTP server, using pure vimscript (no python dependency!). All server operations are asynchronous and this results in a much smoother coding experience.

**Note:** neovim on Windows has been unable to communicate with the stdio server until a (very) recent neovim patch.
If you are using nvim-qt _or_ terminal neovim on Windows, you will require a neovim [nightly build](https://github.com/neovim/neovim/releases/nightly) `NVIM v0.5.0-556` (2020-06-11) or newer, or will need to wait for neovim 0.5 to be released.

**Note to WSL users:** OmniSharp-roslyn stdio version 1.35.3 does _not_ work from WSL, using the Windows server, see [OmniSharp-roslyn #1844](https://github.com/OmniSharp/omnisharp-roslyn/issues/1844).
Install the previous version with `:OmniSharpInstall v1.35.2`

To use the HTTP server instead, add this to your .vimrc:

```vim
let g:OmniSharp_server_stdio = 0
```

Any time `g:OmniSharp_server_stdio` is modified, the server needs to be re-installed with `:OmniSharpInstall`.

## Features

* Contextual code completion
  * Code documentation and type lookup, displayed in popups or the preview window, when available (depends on installed SDKs)
  * Completion Sources are provided for:
    * [asyncomplete-vim](https://github.com/prabirshrestha/asyncomplete.vim)
    * [coc.nvim](https://github.com/neoclide/coc.nvim)
    * [ncm2](https://github.com/ncm2/ncm2)
  * Completion snippets are supported. e.g. Console.WriteLine(TAB) (ENTER) will complete to Console.WriteLine(string value) and expand a dynamic snippet, this will place you in SELECT mode and the first method argument will be selected. 
    * Requires [UltiSnips](https://github.com/SirVer/ultisnips) and supports standard C-x C-o completion as well as completion/autocompletion plugins such as [asyncomplete-vim](https://github.com/prabirshrestha/asyncomplete.vim), [Supertab](https://github.com/ervandew/supertab), [Neocomplete](https://github.com/Shougo/neocomplete.vim) etc.
    * Requires `set completeopt-=preview` when using [Neocomplete](https://github.com/Shougo/neocomplete.vim) because of a compatibility issue with [UltiSnips](https://github.com/SirVer/ultisnips). 

* Jump to the definition of a type/variable/method
* Find symbols interactively (can use plugin: [fzf.vim](https://github.com/junegunn/fzf.vim), [CtrlP](https://github.com/ctrlpvim/ctrlp.vim) or [unite.vim](https://github.com/Shougo/unite.vim))
* Find implementations/derived types
* Find usages *(FZF support set `g:OmniSharp_selector_findusages = 'fzf'`)
* Contextual code actions (unused usings, use var....etc.) (can use plugin: [fzf.vim](https://github.com/junegunn/fzf.vim), [CtrlP](https://github.com/ctrlpvim/ctrlp.vim) or [unite.vim](https://github.com/Shougo/unite.vim))
* Find code issues (unused usings, use base type where possible....etc.) (requires plugin: [ALE](https://github.com/w0rp/ale) or [Syntastic](https://github.com/vim-syntastic/syntastic))
* Find all code issues in solution and populate the quickfix window
* Fix using statements for the current buffer (sort, remove and add any missing using statements where possible)
* Rename refactoring
* Full semantic highlighting
* Code error checking
* Code formatter
* Run unit tests and navigate to failing assertions

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
Install the Vim plugin using your preferred plugin manager:

| Plugin Manager                                       | Command                                                                              |
|------------------------------------------------------|--------------------------------------------------------------------------------------|
| [Vim-plug](https://github.com/junegunn/vim-plug)     | `Plug 'OmniSharp/omnisharp-vim'`                                                     |
| [Vundle](https://github.com/gmarik/vundle)           | `Bundle 'OmniSharp/omnisharp-vim'`                                                   |
| [NeoBundle](https://github.com/Shougo/neobundle.vim) | `NeoBundle 'OmniSharp/omnisharp-vim'`                                                |

... or git:

| ['runtimepath'](http://vimhelp.appspot.com/options.txt.html#%27runtimepath%27) handler | Command                                            |
|------------------------------------------------------|--------------------------------------------------------------------------------------|
| [Vim 8.0+ Native packages](http://vimhelp.appspot.com/repeat.txt.html#packages) | `$ git clone git://github.com/OmniSharp/omnisharp-vim ~/.vim/pack/plugins/start/omnisharp-vim` |
| [Pathogen](https://github.com/tpope/vim-pathogen)    | `$ git clone git://github.com/OmniSharp/omnisharp-vim ~/.vim/bundle/omnisharp-vim`     |

If not using a plugin manager such as Vim-plug (which does this automatically), make sure your .vimrc contains this line:

```vim
filetype indent plugin on
```

### Server
OmniSharp-vim depends on the [OmniSharp-Roslyn](https://github.com/OmniSharp/omnisharp-roslyn) server. The first time OmniSharp-vim tries to open a C# file, it will check for the presence of the server, and if not found it will ask if it should be downloaded. Answer `y` and the latest version will be downloaded and extracted to `~/.cache/omnisharp-vim/omnisharp-roslyn`, ready to use. *Note:* Requires [`curl`](https://curl.haxx.se/) or [`wget`](https://www.gnu.org/software/wget/) on Linux, macOS, Cygwin and WSL.

Running the command `:OmniSharpInstall` in vim will also install/upgrade to the latest OmniSharp-roslyn release.
To install a particular release, including pre-releases, specify the version number like this:

```vim
:OmniSharpInstall v1.35.2
```

*Note:* These methods depend on the `g:OmniSharp_server_stdio` variable to decide which OmniSharp-roslyn server to download. If you are unsure, try using the default stdio option first, and only fall back to HTTP if you have problems.

* **vim8.0+ or neovim**: Use the stdio server, it is used asynchronously and there is no python requirement.

* **< vim8.0**: Use the HTTP server. Your vim must have python (2 or 3) support, and you'll need either [vim-dispatch](https://github.com/tpope/vim-dispatch) or [vimproc.vim](https://github.com/Shougo/vimproc.vim) to be installed

```vim
" Use the stdio version of OmniSharp-roslyn - this is the default
let g:OmniSharp_server_stdio = 1

" Use the HTTP version of OmniSharp-roslyn:
let g:OmniSharp_server_stdio = 0
```

#### Manual installation
To install the server manually, first decide which version (stdio or HTTP) you wish to use, as described above. Download the latest release for your platform from the [OmniSharp-roslyn releases](https://github.com/OmniSharp/omnisharp-roslyn/releases) page. For stdio on a 64-bit Windows system, the `omnisharp.win-x64.zip` package should be downloaded, whereas Mac users wanting to use the HTTP version should select `omnisharp.http-osx.tar.gz` etc.

Extract the binaries and configure your vimrc with the path to the `run` script (Linux and Mac) or `OmniSharp.exe` file (Window), e.g.:

```vim
let g:OmniSharp_server_path = 'C:\OmniSharp\omnisharp.win-x64\OmniSharp.exe'
```
```vim
let g:OmniSharp_server_path = '/home/me/omnisharp/omnisharp.http-linux-x64/run'
```

#### Windows Subsystem for Linux (WSL)
OmniSharp-roslyn can function perfectly well in WSL using linux binaries, if the environment is correctly configured (see [OmniSharp-roslyn](https://github.com/OmniSharp/omnisharp-roslyn) for requirements).
However, if you have the .NET Framework installed in Windows, you may have better results using the Windows binaries.
To do this, let OmniSharp-vim know that you are operating in WSL mode (indicating that file paths need to be translated by OmniSharp-vim from Unix-Windows and back:

```vim
let g:OmniSharp_translate_cygwin_wsl = 1
```

Running `:OmniSharpInstall` from WSL when `g:OmniSharp_translate_cygwin_wsl = 1` results in the Windows version of OmniSharp-roslyn being installed to the standard Windows location `%LocalAppData%\omnisharp-vim\omnisharp-roslyn`.

**Note:** OmniSharp-roslyn stdio version 1.35.3 does _not_ work from WSL, using the Windows server, see [OmniSharp-roslyn #1844](https://github.com/OmniSharp/omnisharp-roslyn/issues/1844).
Install the previous version with `:OmniSharpInstall v1.35.2`

#### Windows: Cygwin
The automatic installation script for cygwin downloads the *Windows* OmniSharp-roslyn release. OmniSharp-vim detects that it is running in a cygwin environment and automatically enables Windows/cygwin file path translations by setting the default value of `g:OmniSharp_translate_cygwin_wsl` to `1`.

**Note:** The Windows stdio server unfortunately does not work from cygwin, so when cygwin is detected (`has('win32unix')`) the HTTP server is used by default.

#### Linux and Mac
OmniSharp-Roslyn requires Mono on Linux and OSX. The roslyn server [releases](https://github.com/OmniSharp/omnisharp-roslyn/releases) come with an embedded Mono, but this can be overridden to use the installed Mono by setting `g:OmniSharp_server_use_mono` in your vimrc. See [The Mono Project](https://www.mono-project.com/download/stable/) for installation details.

```vim
    let g:OmniSharp_server_use_mono = 1
```

Any time `g:OmniSharp_server_use_mono` is modified, the server needs to be re-installed with `:OmniSharpInstall`.

##### libuv
For the HTTP server, OmniSharp-Roslyn also requires [libuv](http://libuv.org/) on Linux and Mac. This is typically a simple install step, e.g. `brew install libuv` on Mac, `apt-get install libuv1-dev` on debian/Ubuntu, `pacman -S libuv` on arch linux, `dnf install libuv libuv-devel` on Fedora/CentOS, etc.

Please note that if your distro has a "dev" package (`libuv1-dev`, `libuv-devel` etc.) then you will probably need it.

**Note:** This is **not** necessary for the default stdio version of OmniSharp-roslyn.

### Install Python (HTTP only)
Install the latest version of python 3 ([Python 3.7](https://www.python.org/downloads/release/python-370/)) or 2 ([Python 2.7.15](https://www.python.org/downloads/release/python-2715/)).
Make sure that you pick correct version of Python to match your vim's architecture (32-bit python for 32-bit vim, 64-bit python for 64-bit vim).

Verify that Python is working inside Vim with

```vim
:echo has('python3') || has('python')
```

**Note:** If you are using the default stdio version of OmniSharp-roslyn, you do not need python.

### Asynchronous command execution
OmniSharp-vim can start the server only if any of the following criteria is met:

* Vim with job control API is used (8.0+)
* neovim with job control API is used
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

This behaviour can be disabled by setting `let g:OmniSharp_start_server = 0` in your vimrc.
You can then start the server manually from within vim with `:OmniSharpStartServer`.

To get completions, open a C# file from your solution within Vim and press `<C-x><C-o>` (that is ctrl x followed by ctrl o) in Insert mode, or use a completion or autocompletion plugin.

To use the other features, you'll want to create key bindings for them. See the example vimrc below for more info.

See the [wiki](https://github.com/OmniSharp/omnisharp-vim/wiki) for more custom configuration examples.

## Semantic Highlighting
OmniSharp-roslyn can provide highlighting information about every symbol of the document.

To highlight a document, use command `:OmniSharpHighlight`.
By default, `.cs` files are automatically highlighted when entering a buffer and leaving insert mode.
To disable automatic highlighting, add this to your .vimrc:

```vim
let g:OmniSharp_highlighting = 0
```

To update highlighting after all text changes, even while in insert mode, use `g:OmniSharp_highlighting = 3` instead.

The `g:OmniSharp_highlight_groups` dictionary is used to configure highlighting:

```vim
let g:OmniSharp_highlight_groups = {
\ 'Comment': 'NonText',
\ 'XmlDocCommentName': 'Identifier',
\ 'XmlDocCommentText': 'NonText'
\}
```

The `:OmniSharpHighlightEcho` command can be used to find out what type of symbol is under the cursor.
See the [wiki](https://github.com/OmniSharp/omnisharp-vim/wiki/Highlighting-configuration) for the full list of symbol types, and configuration details.

**Note:** Full semantic highlighting uses Vim's text properties and neovim's namespaces, and is only available when using the stdio server, not for HTTP server usage.
Check the [wiki](https://github.com/OmniSharp/omnisharp-vim/wiki/Highlighting-configuration#legacy-highlighting) for how to configure the simpler regex-highlighting when using the HTTP server, or older Vim/neovims.

## Diagnostics

Diagnostics are returned from OmniSharp-roslyn in various ways - via linting plugins such as ALE or Syntastic, and using the `:OmniSharpGlobalCodeCheck` command.
These diagnostics come from roslyn and roslyn analyzers, and as such they can be managed at the server level in 2 ways - using [rulesets](https://roslyn-analyzers.readthedocs.io/en/latest/config-analyzer.html), and using an [.editorconfig](https://docs.microsoft.com/en-us/visualstudio/ide/editorconfig-code-style-settings-reference?view=vs-2019) file.

However, not all diagnostics can only be managed by an `.editorconfig` file, and rulesets are not always a good solution as they involve modifying `.csproj` files, which might not suit your project policies - not all project users necessarily use the same analyzers.

OmniSharp-vim provides a global override dictionary, where any diagnostic can be marked as having severity `E`rror, `W`arning or `I`nfo, and for ALE/Syntastic users, a `'subtype': 'Style'` may be specified.
Diagnostics may be ignored completely by setting their `'type'` to `'None'`, in which case they will not be passed to linters, and will not be displayed in `:OmniSharpGlobalCodeCheck` results.

```vim
" IDE0010: Populate switch - display in ALE as `Info`
" IDE0055: Fix formatting - display in ALE as `Warning` style error
" CS8019: Duplicate of IDE0005
" RemoveUnnecessaryImportsFixable: Generic warning that an unused using exists
let g:OmniSharp_diagnostic_overrides = {
\ 'IDE0010': {'type': 'I'},
\ 'IDE0055': {'type': 'W', 'subtype': 'Style'},
\ 'CS8019': {'type': 'None'},
\ 'RemoveUnnecessaryImportsFixable': {'type': 'None'}
\}
```

To find the relevent diagnostic ID, it can be included in diagnostic descriptions (ALE/Syntastic messages and `:OmniSharpGlobalCodeCheck` results) by setting `g:OmniSharp_diagnostic_showid` to 1 - either in your .vimrc, or temporarily via the Vim command line:

```vim
let g:OmniSharp_diagnostic_showid = 1
```

*Note:* Diagnostic overrides are only available in stdio mode, not HTTP mode.

Another method for filtering out diagnostic results is via path exclusion using `g:OmniSharp_diagnostic_exclude_paths`.
This variable is a list of regular expressions that will exclude paths that have a match to any of its entries:

```vim
let g:OmniSharp_diagnostic_exclude_paths = [
\ 'obj\\',
\ '[Tt]emp\\',
\ '\.nuget\\',
\ '\<AssemblyInfo\.cs\>'
\]
```

## Popups

When a recent enough Vim or neovim is used, OmniSharp-vim will use Vim's popup windows or neovim's floating windows in certain situations:

* `:OmniSharpDocumentation`
* `:OmniSharpSignatureHelp`
* `:OmniSharpPreviewDefinition` (including metadata)
* `:OmniSharpPreviewImplementation`
* completion documentation (Vim only)

OmniSharp-vim will use popups by default for Vims/neovims which support them.
To disable popups completely, set `g:OmniSharp_popup` to `0`:

```vim
let g:OmniSharp_popup = 0
```

### Popup mappings

Apart from the insert-completion documentation window, all popups are closeable/scrollable using these mappings:

| Action name    | Default mapping |
|----------------|-----------------|
| `close`        | `<Esc>`         |
| `lineDown`     | `<C-e>`         |
| `lineUp`       | `<C-y>`         |
| `halfPageDown` | `<C-d>`         |
| `halfPageUp`   | `<C-u>`         |
| `pageDown`     | `<C-f>`         |
| `pageUp`       | `<C-b>`         |

Additionally, the signature-help popup window provides the following mappings for navigating through method signatures and selected parameters:

| Action name    | Default mapping |
|----------------|-----------------|
| `sigNext`      | `<C-j>`         |
| `sigPrev`      | `<C-k>`         |
| `sigParamNext` | `<C-l>`         |
| `sigParamPrev` | `<C-h>`         |

These mappings are all configurable, and you can assign more than one mapping for an action.
So to use e.g. `CTRL-N` and `CTRL-P` to navigate between signatures instead of `CTRL-J` and `CTRL-K`, and to use either `CTRL-E`/`CTRL-Y` or `j`/`k` for single line scrolling, use `g:OmniSharp_popup_mappings` like this:

```vim
let g:OmniSharp_popup_mappings = {
\ 'sigNext': '<C-n>',
\ 'sigPrev': '<C-p>',
\ 'lineDown': ['<C-e>', 'j'],
\ 'lineUp': ['<C-y>', 'k']
\}
```

Popups can be closed by using the `close` action mapping (`<Esc>` by default), and also by simply navigating to another line.

### Popup options

Vim and neovim have different options for styling popups.

#### Popup styling for Vim

The popup options from [:help popup_create-arguments](http://vimhelp.appspot.com/popup.txt.html#popup_create-arguments) can be used to style Vim popups.
By default, Vim uses the `Pmenu` highlight group, with no border or padding.
Add a border and padding, and use the `Normal` highlight group like this:

```vim
let g:OmniSharp_popup_options = {
\ 'highlight': 'Normal',
\ 'padding': [1],
\ 'border': [1]
\}
```

See the `:help` link above for options for border characters, border highlight groups etc.

#### Popup styling for neovim

The `g:OmniSharp_popup_options` dictionary is a set of window options which can be set for the popup.
Enable pseudo-transparency and change the highlight group from the default `NormalFloat` to `Normal` like this:

```vim
let g:OmniSharp_popup_options = {
\ 'winblend': 30,
\ 'winhl': 'Normal:Normal'
\}
```

### Popup position

The "documentation" popups (including signature help) are always opened as close as possible to the cursor.
However "buffer" popups (previewing definitions and implementations) may be configured to open in different ways, using the `g:OmniSharp_popup_position` value:

- `atcursor`: (default) Next to the cursor. Height expands to display as much as possible, so this may result in a very high window.
- `peek`: Opens below or above the cursor, with the full width of the current window. Looks like a split, without altering window layout.
- `center`: Centered in the Vim window, filling the entire workspace.


## Configuration

### Example vimrc

```vim
" Use the vim-plug plugin manager: https://github.com/junegunn/vim-plug
" Remember to run :PlugInstall when loading this vimrc for the first time, so
" vim-plug downloads the plugins listed.
silent! if plug#begin('~/.vim/plugged')
Plug 'OmniSharp/omnisharp-vim'
Plug 'w0rp/ale'
call plug#end()
endif

" Don't autoselect first omnicomplete option, show options even if there is only
" one (so the preview documentation is accessible). Remove 'preview', 'popup'
" and 'popuphidden' if you don't want to see any documentation whatsoever.
" Note that neovim does not support `popuphidden` or `popup` yet:
" https://github.com/neovim/neovim/issues/10996
if has('patch-8.1.1880')
  set completeopt=longest,menuone,popuphidden
  " Highlight the completion documentation popup background/foreground the same as
  " the completion menu itself, for better readability with highlighted
  " documentation.
  set completepopup=highlight:Pmenu,border:off
else
  set completeopt=longest,menuone,preview
  " Set desired preview window height for viewing documentation.
  set previewheight=5
endif

" Tell ALE to use OmniSharp for linting C# files, and no other linters.
let g:ale_linters = { 'cs': ['OmniSharp'] }

augroup omnisharp_commands
  autocmd!

  " Show type information automatically when the cursor stops moving.
  " Note that the type is echoed to the Vim command line, and will overwrite
  " any other messages in this space including e.g. ALE linting messages.
  autocmd CursorHold *.cs OmniSharpTypeLookup

  " The following commands are contextual, based on the cursor position.
  autocmd FileType cs nmap <silent> <buffer> gd <Plug>(omnisharp_go_to_definition)
  autocmd FileType cs nmap <silent> <buffer> <Leader>osfu <Plug>(omnisharp_find_usages)
  autocmd FileType cs nmap <silent> <buffer> <Leader>osfi <Plug>(omnisharp_find_implementations)
  autocmd FileType cs nmap <silent> <buffer> <Leader>ospd <Plug>(omnisharp_preview_definition)
  autocmd FileType cs nmap <silent> <buffer> <Leader>ospi <Plug>(omnisharp_preview_implementations)
  autocmd FileType cs nmap <silent> <buffer> <Leader>ost <Plug>(omnisharp_type_lookup)
  autocmd FileType cs nmap <silent> <buffer> <Leader>osd <Plug>(omnisharp_documentation)
  autocmd FileType cs nmap <silent> <buffer> <Leader>osfs <Plug>(omnisharp_find_symbol)
  autocmd FileType cs nmap <silent> <buffer> <Leader>osfx <Plug>(omnisharp_fix_usings)
  autocmd FileType cs nmap <silent> <buffer> <C-\> <Plug>(omnisharp_signature_help)
  autocmd FileType cs imap <silent> <buffer> <C-\> <Plug>(omnisharp_signature_help)

  " Navigate up and down by method/property/field
  autocmd FileType cs nmap <silent> <buffer> [[ <Plug>(omnisharp_navigate_up)
  autocmd FileType cs nmap <silent> <buffer> ]] <Plug>(omnisharp_navigate_down)
  " Find all code errors/warnings for the current solution and populate the quickfix window
  autocmd FileType cs nmap <silent> <buffer> <Leader>osgcc <Plug>(omnisharp_global_code_check)
  " Contextual code actions (uses fzf, CtrlP or unite.vim selector when available)
  autocmd FileType cs nmap <silent> <buffer> <Leader>osca <Plug>(omnisharp_code_actions)
  autocmd FileType cs xmap <silent> <buffer> <Leader>osca <Plug>(omnisharp_code_actions)
  " Repeat the last code action performed (does not use a selector)
  autocmd FileType cs nmap <silent> <buffer> <Leader>os. <Plug>(omnisharp_code_action_repeat)
  autocmd FileType cs xmap <silent> <buffer> <Leader>os. <Plug>(omnisharp_code_action_repeat)

  autocmd FileType cs nmap <silent> <buffer> <Leader>os= <Plug>(omnisharp_code_format)

  autocmd FileType cs nmap <silent> <buffer> <Leader>osnm <Plug>(omnisharp_rename)

  autocmd FileType cs nmap <silent> <buffer> <Leader>osre <Plug>(omnisharp_restart_server)
  autocmd FileType cs nmap <silent> <buffer> <Leader>osst <Plug>(omnisharp_start_server)
  autocmd FileType cs nmap <silent> <buffer> <Leader>ossp <Plug>(omnisharp_stop_server)
augroup END

" Enable snippet completion, using the ultisnips plugin
" let g:OmniSharp_want_snippet=1
```

## Contributing

Pull requests welcome!

We have slack room as well. [Get yourself invited](https://omnisharp.herokuapp.com/) and make sure to join the `#vim` channel.
