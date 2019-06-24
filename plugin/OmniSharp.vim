if exists('g:OmniSharp_loaded') | finish | endif
let g:OmniSharp_loaded = 1

" Get a global temp path that can be used to store temp files for this instance
let g:OmniSharp_temp_dir = get(g:, 'OmniSharp_temp_dir', fnamemodify(tempname(), ':p:h'))

let g:OmniSharp_lookup_metadata = get(g:, 'OmniSharp_lookup_metadata', 1)

let g:OmniSharp_server_stdio = get(g:, 'OmniSharp_server_stdio', 0)

" When g:OmniSharp_server_stdio_quickload = 1, consider server 'loaded' once
" 'Configuration finished' is received.  When this is 0, wait for notification
" that all projects have been loaded.
let g:OmniSharp_server_stdio_quickload = get(g:, 'OmniSharp_server_stdio_quickload', 0)
let g:OmniSharp_server_display_loading = get(g:, 'OmniSharp_server_display_loading', 1)
let g:OmniSharp_server_loading_timeout = get(g:, 'OmniSharp_server_loading_timeout', 30)

" Use mono to start the roslyn server on *nix
let g:OmniSharp_server_use_mono = get(g:, 'OmniSharp_server_use_mono', 0)

let g:OmniSharp_open_quickfix = get(g:, 'OmniSharp_open_quickfix', 1)

let g:OmniSharp_timeout = get(g:, 'OmniSharp_timeout', 1)

let g:OmniSharp_translate_cygwin_wsl = get(g:, 'OmniSharp_translate_cygwin_wsl', has('win32unix'))

let g:OmniSharp_typeLookupInPreview = get(g:, 'OmniSharp_typeLookupInPreview', 0)

let g:OmniSharp_BufWritePreSyntaxCheck = get(g:, 'OmniSharp_BufWritePreSyntaxCheck', 1)
let g:OmniSharp_CursorHoldSyntaxCheck = get(g:, 'OmniSharp_CursorHoldSyntaxCheck', 0)

let g:OmniSharp_sln_list_index = get(g:, 'OmniSharp_sln_list_index', -1)
let g:OmniSharp_sln_list_name = get(g:, 'OmniSharp_sln_list_name', '')

let g:OmniSharp_autoselect_existing_sln = get(g:, 'OmniSharp_autoselect_existing_sln', 1)
let g:OmniSharp_prefer_global_sln = get(g:, 'OmniSharp_prefer_global_sln', 0)
let g:OmniSharp_start_without_solution = get(g:, 'OmniSharp_start_without_solution', 0)

" Automatically start server
let g:OmniSharp_start_server = get(g:, 'OmniSharp_start_server', get(g:, 'Omnisharp_start_server', 1))

let defaultlevel = g:OmniSharp_server_stdio ? 'info' : 'warning'
let g:OmniSharp_loglevel = get(g:, 'OmniSharp_loglevel', defaultlevel)

" Default map of solution files and directories to ports.
" Preserve backwards compatibility with older version "g:OmniSharp_sln_ports
let g:OmniSharp_server_ports = get(g:, 'OmniSharp_server_ports', get(g:, 'OmniSharp_sln_ports', {}))

" Initialise automatic type and interface highlighting
let g:OmniSharp_highlight_types = get(g:, 'OmniSharp_highlight_types', 0)
if g:OmniSharp_highlight_types
  augroup OmniSharp#HighlightTypes
    autocmd!
    autocmd BufEnter *.cs
    \ if OmniSharp#util#CheckCapabilities() |
    \   call OmniSharp#HighlightBuffer() |
    \ endif

    if g:OmniSharp_highlight_types == 2
      autocmd InsertLeave *.cs
      \ if OmniSharp#util#CheckCapabilities() |
      \   call OmniSharp#HighlightBuffer() |
      \ endif
    endif
  augroup END
endif

function! s:ALEWantResults() abort
  if !g:OmniSharp_server_stdio | return | endif
  if getbufvar(g:ale_want_results_buffer, '&filetype') ==# 'cs'
    call ale#sources#OmniSharp#WantResults(g:ale_want_results_buffer)
  endif
endfunction

augroup OmniSharp#Integrations
  autocmd!

  " Initialize OmniSharp as an asyncomplete source
  autocmd User asyncomplete_setup call asyncomplete#register_source({
  \ 'name': 'OmniSharp',
  \ 'whitelist': ['cs'],
  \ 'completor': function('asyncomplete#sources#OmniSharp#completor')
  \})

  " Listen for ALE requests
  autocmd User ALEWantResults call s:ALEWantResults()
augroup END

if !exists('g:OmniSharp_selector_ui')
  let g:OmniSharp_selector_ui = get(filter(
  \   ['unite', 'ctrlp', 'fzf'],
  \   '!empty(globpath(&runtimepath, printf("plugin/%s.vim", v:val), 1))'
  \ ), 0, '')
endif

" Set to 1 when ultisnips is installed
let g:OmniSharp_want_snippet = get(g:, 'OmniSharp_want_snippet', 0)

let g:omnicomplete_fetch_full_documentation = get(g:, 'omnicomplete_fetch_full_documentation', 0)

let g:OmniSharp_proc_debug = get(g:, 'OmniSharp_proc_debug', get(g:, 'omnisharp_proc_debug', 0))

" vim:et:sw=2:sts=2
