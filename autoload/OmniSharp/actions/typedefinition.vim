let s:save_cpo = &cpoptions
set cpoptions&vim

" Navigate to the definition of the symbol under the cursor.
" Optional arguments:
" Callback: When a callback is passed in, it is called after the response is
"           returned (synchronously or asynchronously) with the found
"           location and a flag for whether it is in a file in the project or
"           from the metadata. This is done instead of navigating to the found
"           location.
" editcommand: The command to use to open buffers, e.g. 'split', 'vsplit',
"              'tabedit' or 'edit' (default).
function! OmniSharp#actions#typedefinition#Find(...) abort
  let opts = { 'editcommand': 'edit' }
  if a:0 && type(a:1) == type('') && a:1 !=# ''
    let opts.editcommand = a:1
  endif

  let Callback = function('s:CBGotoDefinition', [opts])

  call s:StdioFind(Callback)
endfunction

function! s:StdioFind(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback]),
  \ 'Parameters': {
  \   'WantMetadata': v:true,
  \ }
  \}
  call OmniSharp#stdio#Request('/gototypedefinition', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  let body = a:response.Body
  if type(body) == type({}) && get(body, 'Definitions', v:null) != v:null
    let definition = body.Definitions[0]

    if g:OmniSharp_lookup_metadata
          \ && type(definition) == type({})
          \ && type(definition.MetadataSource) == type({})
      let Callback = function('s:CBMetadataFind', [a:Callback])
      call s:StdioMetadataFind(Callback, definition)
    else
      let location = OmniSharp#locations#ParseLocation(definition.Location)

      call a:Callback(location, 0)
    endif
  endif
endfunction

function! s:StdioMetadataFind(Callback, definition) abort
  let metadataSource = a:definition.MetadataSource
  let metadataSource.TypeName = substitute(metadataSource.TypeName, '?', '', 'g')

  let opts = {
  \ 'ResponseHandler': function('s:StdioMetadataFindRH', [a:Callback, a:definition]),
  \ 'Parameters': metadataSource
  \}
  call OmniSharp#stdio#Request('/metadata', opts)
endfunction

function! s:StdioMetadataFindRH(Callback, metadata, response) abort
  if !a:response.Success || a:response.Body.Source == v:null | return 0 | endif
  call a:Callback(a:response.Body, a:metadata)
endfunction

function! s:CBMetadataFind(Callback, response, definition) abort
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
  let location = {
  \ 'filename': temp_file,
  \ 'lnum': a:definition.Location.Range.Start.Line,
  \ 'col': a:definition.Location.Range.Start.Column
  \}
  call a:Callback(location, 1)
endfunction

function! s:CBGotoDefinition(opts, location, fromMetadata) abort
  if type(a:location) != type({}) " Check whether a dict was returned
    echo 'Not found'

    let found = 0
  else
    let found = OmniSharp#locations#Navigate(a:location, get(a:opts, 'editcommand', 'edit'))
    if found && a:fromMetadata
      setlocal nomodifiable readonly
    endif
  endif
  return found
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
