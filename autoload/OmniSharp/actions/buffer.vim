let s:save_cpo = &cpoptions
set cpoptions&vim

" Synchronize the buffer contents with the server. By default, contents are only
" sent when there have been changes since the last run.
" Optional argument: A dict containing the following optional items:
"  Callback: funcref to be called after the response is returned (synchronously
"   or asynchronously)
"  Initializing: flag indicating that this is the first request for this buffer
"  SendBuffer: flag indicating that the buffer contents should be sent,
"   regardless of &modified status or b:changedtick
function! OmniSharp#actions#buffer#Update(...) abort
  let opts = a:0 ? a:1 : {}
  let opts.Initializing = get(opts, 'Initializing', 0)
  let opts.SendBuffer = opts.Initializing || get(opts, 'SendBuffer', 0)
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return | endif
  let lasttick = get(b:, 'OmniSharp_UpdateChangeTick', -1)
  if opts.SendBuffer || b:changedtick != lasttick
    let b:OmniSharp_UpdateChangeTick = b:changedtick
    if g:OmniSharp_server_stdio
      let requestOpts = {
      \ 'ResponseHandler': function('s:StdioUpdateRH', [opts]),
      \ 'Initializing': opts.Initializing
      \}
      call OmniSharp#stdio#Request('/updatebuffer', requestOpts)
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

function! s:StdioUpdateRH(opts, response) abort
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
