let s:save_cpo = &cpoptions
set cpoptions&vim

" Optionally accepts a callback function. This can be used to write after
" formatting, for example.
function! OmniSharp#actions#format#Format(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  if g:OmniSharp_server_stdio
    if type(get(b:, 'OmniSharp_metadata_filename')) != type('')
      call s:StdioFormat(function('s:CBFormat', [opts]))
    else
      echomsg 'CodeFormat is not supported in metadata files'
    endif
  else
    call OmniSharp#py#Eval('codeFormat()')
    call OmniSharp#py#CheckForError()
    return s:CBFormat(opts)
  endif
endfunction

function! s:StdioFormat(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFormatRH', [a:Callback]),
  \ 'ExpandTab': &expandtab,
  \ 'Parameters': {
  \   'WantsTextChanges': 1
  \ }
  \}
  call OmniSharp#stdio#Request('/codeformat', opts)
endfunction

function! s:StdioFormatRH(Callback, response) abort
  if !a:response.Success | return | endif
  normal! m'
  let winview = winsaveview()
  call OmniSharp#buffer#Update(a:response.Body)
  call winrestview(winview)
  normal! ``
  call a:Callback()
endfunction

function! s:CBFormat(opts) abort
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
