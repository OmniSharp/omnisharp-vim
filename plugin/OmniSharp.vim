if exists('g:OmniSharp_loaded')
  finish
endif

let g:OmniSharp_loaded = 1

if !has('python')
  echoerr 'Error: OmniSharp requires Vim compiled with +python'
  finish
endif

"Load python/OmniSharp.py
let s:py_path = OmniSharp#util#path_join('python')
exec "python sys.path.append(r'" . s:py_path . "')"
exec 'pyfile ' . fnameescape(OmniSharp#util#path_join(['python', 'Completion.py']))
exec 'pyfile ' . fnameescape(OmniSharp#util#path_join(['python', 'OmniSharp.py']))

let g:OmniSharp_port = get(g:, 'OmniSharp_port', 2000)

"Setup variable defaults
"Default value for the server address
let g:OmniSharp_host = get(g:, 'OmniSharp_host', 'http://localhost:' . g:OmniSharp_port)

"Default value for the timeout value
let g:OmniSharp_timeout = get(g:, 'OmniSharp_timeout', 1)

"Default value for the timeout value
let g:OmniSharp_quickFixLength = get(g:, 'OmniSharp_quickFixLength', 60)

"Don't use the preview window by default
let g:OmniSharp_typeLookupInPreview = get(g:, 'OmniSharp_typeLookupInPreview', 0)

" Auto syntax-check options.
" Default:
" g:OmniSharp_BufWritePreSyntaxCheck = 1
" g:OmniSharp_CursorHoldSyntaxCheck  = 0
let g:OmniSharp_BufWritePreSyntaxCheck = get(g:, 'OmniSharp_BufWritePreSyntaxCheck', 1)
let g:OmniSharp_CursorHoldSyntaxCheck = get(g:, 'OmniSharp_CursorHoldSyntaxCheck', 0)

let g:OmniSharp_sln_list_index =
\ get( g:, 'OmniSharp_sln_list_index', -1 )

let g:OmniSharp_sln_list_name =
\ get( g:, 'OmniSharp_sln_list_name', '' )

let g:OmniSharp_autoselect_existing_sln =
\ get( g:, 'OmniSharp_autoselect_existing_sln', 1 )

let g:OmniSharp_running_slns = []

" Automatically start server
if !exists('g:Omnisharp_start_server')
  let g:Omnisharp_start_server = 1
endif

" Automatically stop server
" g:Omnisharp_stop_server == 0  :: never stop server
" g:Omnisharp_stop_server == 1  :: always ask
" g:Omnisharp_stop_server == 2  :: stop if this vim started
if !exists('g:Omnisharp_stop_server')
  let g:Omnisharp_stop_server = 2
endif

" Start server without solution file
let g:OmniSharp_start_without_solution = get(g:, 'OmniSharp_start_without_solution', 0)

" Provide custom server configuration file name
let g:OmniSharp_server_config_name =
\ get(g:, 'OmniSharp_server_config_name', 'omnisharp.json')

if g:Omnisharp_stop_server==1
  au VimLeavePre * call OmniSharp#AskStopServerIfRunning()
endif

if !exists('g:Omnisharp_highlight_user_types')
  let g:Omnisharp_highlight_user_types = 0
endif

if !exists('g:OmniSharp_selector_ui')
  let g:OmniSharp_selector_ui = get(filter(
  \   ['unite', 'ctrlp', 'fzf'],
  \   '!empty(globpath(&runtimepath, printf("autoload/%s.vim", v:val), 1))'
  \ ), 0, '')
endif

" Set g:OmniSharp_server_type to 'roslyn' or 'v1'
let g:OmniSharp_server_type = get(g:, 'OmniSharp_server_type', 'v1')

" Set default for snippet based completions
let g:OmniSharp_want_snippet = get(g:, 'OmniSharp_want_snippet', 0)

if !exists('g:OmniSharp_prefer_global_sln')
  let g:OmniSharp_prefer_global_sln = 0
endif
