let s:save_cpo = &cpoptions
set cpoptions&vim

let s:stdiologfile = expand('<sfile>:p:h:h:h') . '/log/stdio.log'

function! OmniSharp#log#Log(job, message, loglevel) abort
  call s:Init(a:job)
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

" Log a decoded server message
function! OmniSharp#log#LogServer(job, raw, msg) abort
  call s:Init(a:job)
  if !has_key(a:msg, 'Body') || type(a:msg.Body) != type({})
    call writefile(['RAW: ' . a:raw], a:job.logfile, 'a')
  elseif get(a:msg, 'Event', '') ==? 'log'
    " Attempt to normalise newlines, which can be \%uD\%u0 in Windows and \%u0
    " in linux
    let message = substitute(a:msg.Body.Message, '\%uD\ze\%u0', '', 'g')
    let lines = split(message, '\%u0', 1)
    let lines[0] = '        ' . lines[0]
    let prefix = s:LogLevelPrefix(a:msg.Body.LogLevel)
    call insert(lines, printf('[%s]: %s', prefix, a:msg.Body.Name))
    call writefile(lines, a:job.logfile, 'a')
  else
    call writefile(['ELSE: ' . a:raw], a:job.logfile, 'a')
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

function! s:LogLevelPrefix(loglevel) abort
  if a:loglevel ==# 'TRACE'
    return 'trce'
  elseif a:loglevel ==# 'DEBUG'
    return 'dbug'
  elseif a:loglevel ==# 'INFORMATION'
    return 'info'
  elseif a:loglevel ==# 'WARNING'
    return 'warn'
  elseif a:loglevel ==# 'ERROR'
    return 'fail'
  elseif a:loglevel ==# 'CRITICAL'
    return 'crit'
  else
    return a:loglevel
  endif
endfunction

function! s:Init(job) abort
  if has_key(a:job, 'logfile')
    return
  endif
  let logfile = strftime('%Y%m%d%H%M_') . get(a:job, 'pid') . '_omnisharp.log'
  let logfile = fnamemodify(s:stdiologfile, ':h') . '/' . logfile
  " Add the new log filename to the standard log, so it can be opened with `gf`
  call writefile([logfile], s:stdiologfile, 'a')
  let a:job.logfile = logfile
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
