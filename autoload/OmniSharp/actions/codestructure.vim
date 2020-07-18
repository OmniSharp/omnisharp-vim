let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#codestructure#Get(bufnr, sendbuffer, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeStructureRH', [a:bufnr, a:Callback]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': a:sendbuffer
  \}
  call OmniSharp#stdio#Request('/v2/codestructure', opts)
endfunction

function! s:CodeStructureRH(bufnr, Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(a:bufnr, a:response.Body.Elements)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
