let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#project#Get(bufnr, Callback) abort
  if has_key(OmniSharp#GetHost(a:bufnr), 'project')
    call a:Callback()
    return
  endif
  let opts = {
  \ 'ResponseHandler': function('s:ProjectRH', [a:Callback, a:bufnr]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0
  \}
  call OmniSharp#stdio#Request('/project', opts)
endfunction

function! s:ProjectRH(Callback, bufnr, response) abort
  if !a:response.Success | return | endif
  let host = getbufvar(a:bufnr, 'OmniSharp_host')
  let host.project = a:response.Body
  call a:Callback()
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
