let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#navigate#Down() abort
  call s:Navigate(1)
endfunction

function! OmniSharp#actions#navigate#Up() abort
  call s:Navigate(0)
endfunction

function! s:Navigate(down) abort
  if g:OmniSharp_server_stdio
    let opts = {
    \ 'ResponseHandler': function('s:NavigateRH')
    \}
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
