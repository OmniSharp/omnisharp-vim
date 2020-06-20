let s:save_cpo = &cpoptions
set cpoptions&vim

let s:stdiologfile = expand('<sfile>:p:h:h:h') . '/log/stdio.log'

function! OmniSharp#log#Log(job, message, loglevel) abort
  if !has_key(a:job, 'logfile')
    let a:job.logfile = s:Init(a:job)
  endif
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
    call writefile([a:message], a:job.logfile, 'a')
  endif
endfunction

function! OmniSharp#log#Open(...)
  if g:OmniSharp_server_stdio
    let logfile = s:stdiologfile
    if exists('b:OmniSharp_host')
      let job = OmniSharp#GetHost().job
      if type(job) == type({})
        let logfile = get(job, 'logfile', s:stdiologfile)
      endif
    endif
  else
    let logfile = OmniSharp#py#Eval('getLogFile()')
    if OmniSharp#py#CheckForError() | return | endif
  endif
  let cmd = (a:0 && type(a:1) == type('') && len(a:1)) ? a:1 : 'edit'
  exec cmd logfile
endfunction

function! s:Init(job) abort
  let logfile = strftime('%Y%m%d%H%M_') . get(a:job, 'pid') . '_omnisharp.log'
  let logfile = fnamemodify(s:stdiologfile, ':h') . '/' . logfile
  " Add the new log filename to the standard log, so it can be opened with `gf`
  call writefile([logfile], s:stdiologfile, 'a')
  return logfile
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
