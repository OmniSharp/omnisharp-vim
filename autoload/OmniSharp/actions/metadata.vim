let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#metadata#Find(open_in_preview, metadata, opts) abort
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBGotoMetadata', [a:open_in_preview, a:opts])
    call s:StdioFind(Callback, a:metadata)
    return 1
  else
    echomsg 'GotoMetadata is not supported with the HTTP OmniSharp server. '
    \ . 'Please consider upgrading to the stdio version.'
    return 0
  endif
endfunction

function! s:StdioFind(Callback, metadata) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback, a:metadata]),
  \ 'Parameters': a:metadata.MetadataSource
  \}
  call OmniSharp#stdio#Request('/metadata', opts)
endfunction

function! s:StdioFindRH(Callback, metadata, response) abort
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
