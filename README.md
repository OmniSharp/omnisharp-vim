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
* Contextual code actions (sort usings, use var....etc.)
* Rename refactoring
* Semantic type highlighting
* Lookup type information of an type/variable/method
	* Can be printed to the status line or in the preview window
* Simple syntax error highlighting
* Integrated xbuild/msbuild (can run asynchronously if vim dispatch is installed)
* Code formatter
* Add file to project (currently will only add .cs files to a .csproj file)
* Add reference. Supports project and file reference. GAC referencing todo.
	* Usage: :OmniSharpAddReference path_to_reference


##Screenshots
####Auto Complete
![OmniSharp screenshot](https://f.cloud.github.com/assets/667194/514371/dc03e2bc-be56-11e2-9745-c3202335e5ab.png)

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
:python print "hi"
```

###Install vim-dispatch
The vim plugin [vim-dispatch] (https://github.com/tpope/vim-dispatch) is needed to make Omnisharp start the server automatically.
Use your favorite way to install it.


## How to use (read: run the server)

By default, the server is started automatically if you have vim-dispatch installed when you open a .cs file.
It tries to detect your solution file (.sln) and starts the OmniSharp server passing the path to the solution file.
This behaviour can be disabled by setting `let g:Omnisharp_start_server = 0` in your vimrc.

When your close vim, and the omnisharp server is running, vim will ask you if you want to stop the OmniSharp server.
This behaviour can be disabled by setting `let g:Omnisharp_stop_server = 0` in your vimrc.

You can alternatively start the Omnisharp server manually:

	[mono] OmniSharp.exe -p (portnumber) -s (path\to\sln)


OmniSharp listens to requests from Vim on port 2000 by default, so make sure that your firewall is configured to accept requests from localhost on this port.
Also if you are running OmniSharp as a non-privileged user, or without UAC elevation on Vista or later, you will need to run the following

```
netsh http add urlacl url=http://+:2000/ user=DOMAIN\user
```

This will give your user permission to bind to port 2000.

To get completions, open one of the C# files from the solution within Vim and press Ctrl-X Ctrl-O in Insert mode 
(or just TAB if you have [SuperTab] (https://github.com/ervandew/supertab) installed). 
Repeat to cycle through completions, or use the cursor keys (eugh!)

If you prefer to get completions as you are typing, then you should take a look at [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)
or [NeoComplCache](https://github.com/Shougo/neocomplcache.vim). 

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
let g:OmniSharp_typeLookupInPreview = 1

"Showmatch significantly slows down omnicomplete
"when the first match contains parentheses.
set noshowmatch

"Super tab settings
"let g:SuperTabDefaultCompletionType = 'context'
"let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
"let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
"let g:SuperTabClosePreviewOnPopupClose = 1

"don't autoselect first item in omnicomplete, show if only one item (for preview)
set completeopt=longest,menuone,preview

nnoremap <F5> :wa!<cr>:OmniSharpBuild<cr>
" Builds can run asynchronously with vim-dispatch installed
"nnoremap <F5> :wa!<cr>:OmniSharpBuildAsync<cr>

nnoremap <F12> :OmniSharpGotoDefinition<cr>
nnoremap gd :OmniSharpGotoDefinition<cr>
nnoremap <leader>fi :OmniSharpFindImplementations<cr>
nnoremap <leader>ft :OmniSharpFindType<cr>
nnoremap <leader>fs :OmniSharpFindSymbol<cr>
nnoremap <leader>fu :OmniSharpFindUsages<cr>
nnoremap <leader>fm :OmniSharpFindMembersInBuffer<cr>
nnoremap <leader>tt :OmniSharpTypeLookup<cr>
"I find contextual code actions so useful that I have it mapped to the spacebar
nnoremap <space> :OmniSharpGetCodeActions<cr>

" rename with dialog
nnoremap nm :OmniSharpRename<cr>
nnoremap <F2> :OmniSharpRename<cr>      
" rename without dialog - with cursor on the symbol to rename... ':Rename newname'
command! -nargs=1 Rename :call OmniSharp#RenameTo("<args>")
" Force OmniSharp to reload the solution. Useful when switching branches etc.
nnoremap <leader>rl :OmniSharpReloadSolution<cr>
nnoremap <leader>cf :OmniSharpCodeFormat<cr>
nnoremap <leader>tp :OmniSharpAddToProject<cr>
" (Experimental - uses vim-dispatch or vimproc plugin) - Start the omnisharp server for the current solution
nnoremap <leader>ss :OmniSharpStartServer<cr>
nnoremap <leader>sp :OmniSharpStopServer<cr>
nnoremap <leader>th :OmniSharpHighlightTypes<cr>
"Don't ask to save when changing buffers (i.e. when jumping to a type definition)
set hidden
```

OmniSharp works very well with the [NeoComplCache] (https://github.com/Shougo/neocomplcache) plugin. Used in conjunction with
NeoComplCache, OmniSharp can provide an experience matching or even bettering
Visual Studio intellisense. Completions are provided as you type.
These are my settings to use with this plugin. Don't set these unless you use this plugin! 
If you improve these settings, I'd like to hear about it!

```vim
let g:neocomplcache_enable_at_startup = 1
" Use smartcase.
let g:neocomplcache_enable_smart_case = 1
" Use camel case completion.
let g:neocomplcache_enable_camel_case_completion = 1
" Use underscore completion.
let g:neocomplcache_enable_underbar_completion = 1
" Sets minimum char length of syntax keyword.
let g:neocomplcache_min_syntax_length = 0
" buffer file name pattern that locks neocomplcache. e.g. ku.vim or fuzzyfinder 
"let g:neocomplcache_lock_buffer_name_pattern = '\*ku\*'

let g:neocomplcache_enable_auto_close_preview = 0
" Define keyword, for minor languages
if !exists('g:neocomplcache_keyword_patterns')
  let g:neocomplcache_keyword_patterns = {}
endif
let g:neocomplcache_keyword_patterns['default'] = '\h\w*'

" Plugin key-mappings.
inoremap <expr><C-g>     neocomplcache#undo_completion()
inoremap <expr><C-l>     neocomplcache#complete_common_string()

" SuperTab like snippets behavior.
"imap <expr><TAB> neocomplcache#sources#snippets_complete#expandable() ? "\<Plug>(neocomplcache_snippets_expand)" : pumvisible() ? "\<C-n>" : "\<TAB>"

" Recommended key-mappings.
" <CR>: close popup and save indent.
inoremap <expr><CR> pumvisible() ? neocomplcache#close_popup() : "\<CR>"
inoremap <expr>.  neocomplcache#close_popup() . "."
inoremap <expr>(  neocomplcache#close_popup() . "("
inoremap <expr>)  neocomplcache#close_popup() . ")"
inoremap <expr><space>  neocomplcache#close_popup() . " "
inoremap <expr>;  neocomplcache#close_popup() . ";"
" <TAB>: completion.
inoremap <expr><TAB>  pumvisible() ? "\<C-n>" : "\<TAB>"
" <C-h>, <BS>: close popup and delete backword char.
inoremap <expr><C-h> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><BS> neocomplcache#smart_close_popup()."\<C-h>"
inoremap <expr><C-y>  neocomplcache#close_popup()
inoremap <expr><C-e>  neocomplcache#cancel_popup()
inoremap <expr><ESC> pumvisible() ? neocomplcache#cancel_popup() : "\<esc>"

" AutoComplPop like behavior.
let g:neocomplcache_enable_auto_select = 1

" Shell like behavior(not recommended).
set completeopt+=longest
"let g:neocomplcache_disable_auto_complete = 1
"inoremap <expr><TAB>  pumvisible() ? "\<Down>" : "\<TAB>"
"inoremap <expr><CR>  neocomplcache#smart_close_popup() . "\<CR>"


" Enable heavy omni completion, which require computational power and may stall the vim. 
if !exists('g:neocomplcache_omni_patterns')
  let g:neocomplcache_omni_patterns = {}
endif
let g:neocomplcache_omni_patterns.ruby = '[^. *\t]\.\w*\|\h\w*::'
let g:neocomplcache_omni_patterns.cs = '.*'
"autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
let g:neocomplcache_omni_patterns.php = '[^. \t]->\h\w*\|\h\w*::'
let g:neocomplcache_omni_patterns.c = '\%(\.\|->\)\h\w*'
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

