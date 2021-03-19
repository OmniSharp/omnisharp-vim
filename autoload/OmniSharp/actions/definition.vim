let s:save_cpo = &cpoptions
set cpoptions&vim

" Navigate to the definition of the symbol under the cursor.
" Optional arguments:
" Callback: When a callback is passed in, it is called after the response is
"           returned (synchronously or asynchronously) with a boolean 'found'
"           result.
" editcommand: The command to use to open buffers, e.g. 'split', 'vsplit',
"              'tabedit' or 'edit' (default).
function! OmniSharp#actions#definition#Find(...) abort
  let opts = { 'editcommand': 'edit' }
  if a:0 && type(a:1) == type(function('tr'))
    let opts.Callback = a:1
  endif
  if a:0 > 1 && type(a:2) == type(function('tr'))
    let opts.Callback = a:2
  endif
    if a:0 && type(a:1) == type('') && a:1 !=# ''
      let opts.editcommand = a:1
    endif
  if a:0 > 1 && type(a:2) == type('') && a:1 !=# ''
    let opts.editcommand = a:2
  endif
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBGotoDefinition', [opts])
    call s:StdioFind(Callback)
  else
    let loc = OmniSharp#py#Eval('gotoDefinition()')
    if OmniSharp#py#CheckForError() | return 0 | endif
    " Mock metadata info for old server based setups
    return s:CBGotoDefinition(opts, loc, { 'MetadataSource': {}})
  endif
endfunction

function! OmniSharp#actions#definition#Preview(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBPreviewDefinition', [opts])
    call s:StdioFind(Callback)
  else
    let loc = OmniSharp#py#Eval('gotoDefinition()')
    if OmniSharp#py#CheckForError() | return 0 | endif
    call s:CBPreviewDefinition({}, loc, {})
  endif
endfunction

function! s:StdioFind(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback]),
  \ 'Parameters': {
  \   'WantMetadata': v:true,
  \ }
  \}
  call OmniSharp#stdio#Request('/gotodefinition', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  let body = a:response.Body
  if type(body) == type({}) && get(body, 'FileName', v:null) != v:null
    call a:Callback(OmniSharp#locations#Parse([body])[0], body)
  else
    call a:Callback(0, body)
  endif
endfunction

function! s:CBGotoDefinition(opts, location, metadata) abort
  let went_to_metadata = 0
  if type(a:location) != type({}) " Check whether a dict was returned
    if g:OmniSharp_lookup_metadata
    \ && type(a:metadata) == type({})
    \ && type(a:metadata.MetadataSource) == type({})
      let found = s:MetadataFind(0, a:metadata, a:opts)
      let went_to_metadata = 1
    else
      echo 'Not found'
      let found = 0
    endif
  else
    let found = OmniSharp#locations#Navigate(a:location, a:opts.editcommand)
  endif
  if has_key(a:opts, 'Callback') && !went_to_metadata
    call a:opts.Callback(found)
  endif
  return found
endfunction

function! s:CBPreviewDefinition(opts, location, metadata) abort
  if type(a:location) != type({}) " Check whether a dict was returned
    if g:OmniSharp_lookup_metadata
    \ && type(a:metadata) == type({})
    \ && type(a:metadata.MetadataSource) == type({})
      let found = s:MetadataFind(1, a:metadata, a:opts)
    else
      echo 'Not found'
    endif
  else
    call OmniSharp#locations#Preview(a:location)
    echo OmniSharp#locations#Modify(a:location).filename
  endif
endfunction

function! s:MetadataFind(open_in_preview, metadata, opts) abort
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBGotoMetadata', [a:open_in_preview, a:opts])
    call s:StdioMetadataFind(Callback, a:metadata)
    return 1
  else
    echomsg 'GotoMetadata is not supported with the HTTP OmniSharp server. '
    \ . 'Please consider upgrading to the stdio version.'
    return 0
  endif
endfunction

function! s:StdioMetadataFind(Callback, metadata) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioMetadataFindRH', [a:Callback, a:metadata]),
  \ 'Parameters': a:metadata.MetadataSource
  \}
  call OmniSharp#stdio#Request('/metadata', opts)
endfunction

function! s:StdioMetadataFindRH(Callback, metadata, response) abort
  if !a:response.Success || a:response.Body.Source == v:null | return 0 | endif
  call a:Callback(a:response.Body, a:metadata)
endfunction

function! s:CBGotoMetadata(open_in_preview, opts, response, metadata) abort
  let host = OmniSharp#GetHost()
  let metadata_filename = fnamemodify(
  \ OmniSharp#util#TranslatePathForClient(a:response.SourceName), ':t')
  let temp_file = OmniSharp#util#TempDir() . '/' . metadata_filename
  let lines = split(a:response.Source, "\n", 1)
  let lines = map(lines, {i,v -> substitute(v, '\r', '', 'g')})
  call writefile(lines, temp_file, 'b')
  let bufnr = bufadd(temp_file)
  call setbufvar(bufnr, 'OmniSharp_host', host)
  call setbufvar(bufnr, 'OmniSharp_metadata_filename', a:response.SourceName)
  let jumped_from_preview = &previewwindow
  let location = {
  \ 'filename': temp_file,
  \ 'lnum': a:metadata.Line,
  \ 'col': a:metadata.Column
  \}
  if a:open_in_preview
    call OmniSharp#locations#Preview(location)
  else
    call OmniSharp#locations#Navigate(location, get(a:opts, 'editcommand', 'edit'))
    setlocal nomodifiable readonly
  endif
  if a:open_in_preview && !jumped_from_preview && &previewwindow
    silent wincmd p
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(1) " found
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
