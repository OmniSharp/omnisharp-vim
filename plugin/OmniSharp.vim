if exists('g:OmniSharp_loaded')
  finish
endif

let g:OmniSharp_loaded = 1

if !(has('python') || has('python3'))
  echoerr 'Error: OmniSharp requires Vim compiled with +python or +python3'
  finish
endif

" Select a server: one of 'roslyn' or 'v1'
let g:OmniSharp_server_type = get(g:, 'OmniSharp_server_type', 'roslyn')

" Use mono to start the roslyn server on *nix
let g:OmniSharp_server_use_mono = get(g:, 'OmniSharp_server_use_mono', 0)

let g:OmniSharp_quickFixLength = get(g:, 'OmniSharp_quickFixLength', 60)

let g:OmniSharp_timeout = get(g:, 'OmniSharp_timeout', 1)

let g:OmniSharp_translate_cygwin_wsl = get(g:, 'OmniSharp_translate_cygwin_wsl', 0)

let g:OmniSharp_typeLookupInPreview = get(g:, 'OmniSharp_typeLookupInPreview', 0)

let g:OmniSharp_BufWritePreSyntaxCheck = get(g:, 'OmniSharp_BufWritePreSyntaxCheck', 1)
let g:OmniSharp_CursorHoldSyntaxCheck = get(g:, 'OmniSharp_CursorHoldSyntaxCheck', 0)

let g:OmniSharp_sln_list_index = get(g:, 'OmniSharp_sln_list_index', -1)
let g:OmniSharp_sln_list_name = get(g:, 'OmniSharp_sln_list_name', '')

let g:OmniSharp_autoselect_existing_sln = get(g:, 'OmniSharp_autoselect_existing_sln', 1)
let g:OmniSharp_prefer_global_sln = get(g:, 'OmniSharp_prefer_global_sln', 0)
let g:OmniSharp_start_without_solution = get(g:, 'OmniSharp_start_without_solution', 0)

let g:OmniSharp_running_slns = []

" Automatically start server
let g:OmniSharp_start_server = get(g:, 'OmniSharp_start_server', get(g:, 'Omnisharp_start_server', 1))

" Automatically stop server
" g:OmniSharp_stop_server == 0  :: never stop server
" g:OmniSharp_stop_server == 1  :: always ask
" g:OmniSharp_stop_server == 2  :: stop if this vim started
let g:OmniSharp_stop_server = get(g:, 'OmniSharp_stop_server', get(g:, 'Omnisharp_stop_server', 2))

if g:OmniSharp_stop_server == 1
  autocmd VimLeavePre * call OmniSharp#AskStopServerIfRunning()
endif

" Provide custom server configuration file name
let g:OmniSharp_server_config_name = get(g:, 'OmniSharp_server_config_name', 'omnisharp.json')

" Initialize OmniSharp as an asyncomplete source
autocmd User asyncomplete_setup call asyncomplete#register_source({
\   'name': 'OmniSharp',
\   'whitelist': ['cs'],
\   'completor': function('asyncomplete#sources#OmniSharp#completor')
\ })

if !exists('g:OmniSharp_selector_ui')
  let g:OmniSharp_selector_ui = get(filter(
  \   ['unite', 'ctrlp', 'fzf'],
  \   '!empty(globpath(&runtimepath, printf("plugin/%s.vim", v:val), 1))'
  \ ), 0, '')
endif

" Set to 1 when ultisnips is installed
let g:OmniSharp_want_snippet = get(g:, 'OmniSharp_want_snippet', 0)

let g:OmniSharp_proc_debug = get(g:, 'OmniSharp_proc_debug', get(g:, 'omnisharp_proc_debug', 0))
