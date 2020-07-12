let s:save_cpo = &cpoptions
set cpoptions&vim

" Optional arguments:
" - callback: funcref to be called after the response is returned (synchronously
"   or asynchronously)
" - initializing: flag indicating that this is the first request for this buffer
" - sendBuffer: flag indicating that the buffer contents should be sent,
"   regardless of &modified status or b:changedtick
function! OmniSharp#actions#buffer#Update(...) abort
  let cb = a:0 && type(a:1) == type(function('tr')) ? { 'Callback': a:1 } : {}
  let initializing = a:0 > 1 && a:2 is 1
  let sendBuffer = initializing || (a:0 > 2 ? a:3 : 0)
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return | endif
  let lasttick = get(b:, 'OmniSharp_UpdateChangeTick', -1)
  if initializing || sendBuffer || b:changedtick != lasttick
    let b:OmniSharp_UpdateChangeTick = b:changedtick
    if g:OmniSharp_server_stdio
      let opts = {
      \ 'ResponseHandler': function('s:StdioUpdateRH', [cb]),
      \ 'Initializing': initializing
      \}
      call OmniSharp#stdio#Request('/updatebuffer', opts)
    else
      if !OmniSharp#IsServerRunning() | return | endif
      call OmniSharp#py#Eval('updateBuffer()')
      call OmniSharp#py#CheckForError()
      if has_key(cb, 'Callback')
        call cb.Callback()
      endif
    endif
  endif
endfunction

function! s:StdioUpdateRH(opts, response) abort
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
