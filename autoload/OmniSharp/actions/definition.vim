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
      let found = OmniSharp#actions#metadata#Find(0, a:metadata, a:opts)
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
      let found = OmniSharp#actions#metadata#Find(1, a:metadata, a:opts)
    else
      echo 'Not found'
    endif
  else
    call OmniSharp#locations#Preview(a:location)
    echo OmniSharp#locations#Modify(a:location).filename
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
