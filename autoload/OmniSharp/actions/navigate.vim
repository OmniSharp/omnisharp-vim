let s:save_cpo = &cpoptions
set cpoptions&vim

" Navigate to the next member definition in the class.
" Optional arguments:
" Callback: When a callback is passed in, it is called after the response is
"           returned with the member location. No navigation is performed when a
"           callback is passed in.
function! OmniSharp#actions#navigate#Down(...) abort
  call s:Navigate(1, a:0 ? a:1 : function('OmniSharp#locations#Navigate'))
endfunction

" See OmniSharp#actions#navigate#Down
function! OmniSharp#actions#navigate#Up(...) abort
  call s:Navigate(0, a:0 ? a:1 : function('OmniSharp#locations#Navigate'))
endfunction

function! s:Navigate(down, Callback) abort
  if g:OmniSharp_server_stdio
    let RH = function('s:StdioNavigateRH', [a:Callback])
    let opts = { 'ResponseHandler': RH }
    call OmniSharp#stdio#Request(a:down ? '/navigatedown' : '/navigateup', opts)
  else
    let loc = OmniSharp#py#Eval(a:down ? 'navigateDown()' : 'navigateUp()')
    if OmniSharp#py#CheckForError() | return | endif
    call a:Callback(loc)
  endif
endfunction

function! s:StdioNavigateRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse([a:response.Body])[0])
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
