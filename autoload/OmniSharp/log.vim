let s:save_cpo = &cpoptions
set cpoptions&vim

let s:stdiologfile = expand('<sfile>:p:h:h:h') . '/log/stdio.log'

function! OmniSharp#log#Log(message, loglevel) abort
  let logit = 0
  if g:OmniSharp_loglevel ==? 'debug'
    " Log everything
    let logit = 1
  elseif g:OmniSharp_loglevel ==? 'info'
    let logit = a:loglevel ==# 'info'
  else
    " g:OmniSharp_loglevel ==? 'none'
  endif
  if logit
    call writefile([a:message], s:stdiologfile, 'a')
  endif
endfunction

function! OmniSharp#log#Open(...)
  if g:OmniSharp_server_stdio
    let logfile = s:stdiologfile
  else
    let logfile = OmniSharp#py#Eval('getLogFile()')
    if OmniSharp#py#CheckForError() | return | endif
  endif
  let cmd = (a:0 && type(a:1) == type('') && len(a:1)) ? a:1 : 'edit'
  exec cmd logfile
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
