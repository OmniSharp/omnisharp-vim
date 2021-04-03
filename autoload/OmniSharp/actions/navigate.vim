let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#navigate#Down(...) abort
  if a:0 > 0
    let Callback = a:1
    call s:Navigate(1, Callback)
  else
    call s:Navigate(1)
  endif
endfunction

function! OmniSharp#actions#navigate#Up(...) abort
  if a:0 > 0
    let Callback = a:1
    call s:Navigate(0, Callback)
  else
    call s:Navigate(0)
  endif
endfunction

function! s:Navigate(down, ...) abort
  if g:OmniSharp_server_stdio
    let Callback = a:0 ? a:1 : function('s:NavigateRH')
    let opts = { 'ResponseHandler': Callback }
    call OmniSharp#stdio#Request(a:down ? '/navigatedown' : '/navigateup', opts)
  else
    call OmniSharp#py#Eval(a:down ? 'navigateDown()' : 'navigateUp()')
    call OmniSharp#py#CheckForError()
  endif
endfunction

function! s:NavigateRH(response) abort
  if !a:response.Success | return | endif
  normal! m'
  call cursor(a:response.Body.Line, a:response.Body.Column)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
