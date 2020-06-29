let s:save_cpo = &cpoptions
set cpoptions&vim

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously)
function! OmniSharp#actions#buffer#Update(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  let initializing = a:0 > 1
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return | endif
  if initializing ||  b:changedtick != get(b:, 'OmniSharp_UpdateChangeTick', -1)
    let b:OmniSharp_UpdateChangeTick = b:changedtick
    if g:OmniSharp_server_stdio
      if initializing
        let opts.Initializing = 1
      endif
      call s:StdioUpdate(opts)
    else
      if !OmniSharp#IsServerRunning() | return | endif
      call OmniSharp#py#Eval('updateBuffer()')
      call OmniSharp#py#CheckForError()
      if has_key(opts, 'Callback')
        call opts.Callback()
      endif
    endif
  endif
endfunction

function! s:StdioUpdate(opts) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioUpdateRH', [a:opts])
  \}
  if has_key(a:opts, 'Initializing')
    let opts.Initializing = 1
  endif
  call OmniSharp#stdio#Request('/updatebuffer', opts)
endfunction

function! s:StdioUpdateRH(opts, response) abort
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
