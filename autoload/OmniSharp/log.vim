let s:save_cpo = &cpoptions
set cpoptions&vim

if has('win32')
  let default_log_dir = expand('<sfile>:p:h:h:h') . '\log'
else
  let default_log_dir = expand('<sfile>:p:h:h:h') . '/log'
end

let s:logdir = get(g:, 'OmniSharp_log_dir', default_log_dir)
let s:stdiologfile = s:logdir . '/stdio.log'

" Make the log directory if it doesn't exist
if !isdirectory(s:logdir)
  call mkdir(s:logdir, 'p')
end

function! OmniSharp#log#GetLogDir() abort
  return s:logdir
endfunction

" Log from OmniSharp-vim
function! OmniSharp#log#Log(job, message, ...) abort
  if g:OmniSharp_loglevel ==? 'none' | return | endif
  call s:Init(a:job)
  let debug = a:0 && a:1
  if g:OmniSharp_loglevel !=? 'info' || !debug
    call writefile([a:message], a:job.logfile, 'a')
  endif
endfunction

" Log a decoded server message
function! OmniSharp#log#LogServer(job, raw, msg) abort
  if g:OmniSharp_loglevel ==? 'none' | return | endif
  call s:Init(a:job)
  if get(g:, 'OmniSharp_proc_debug')
    call writefile([a:raw], a:job.logfile, 'a')
  elseif !has_key(a:msg, 'Body') || type(a:msg.Body) != type({})
    return
  elseif !has_key(a:msg, 'Event')
    return
  elseif get(a:msg, 'Event', '') ==# 'log'
    " Attempt to normalise newlines, which can be \%uD\%u0 in Windows and \%u0
    " in linux
    let message = substitute(a:msg.Body.Message, '\%uD\ze\%u0', '', 'g')
    let lines = split(message, '\%u0', 1)
    if a:msg.Body.Name ==# 'OmniSharp.Roslyn.BufferManager'
      let line0 = '        ' . lines[0]
      if lines[0] =~# '^\s*Updating file .\+ with new text:$'
        " Strip the trailing ':'
        let line0 = line0[:-2]
      endif
      " The server sends the full content of the buffer. Don't log it.
      let prefix = s:LogLevelPrefix(a:msg.Body.LogLevel)
      let lines = [printf('[%s]: %s', prefix, a:msg.Body.Name), line0]
      call writefile(lines, a:job.logfile, 'a')
    elseif g:OmniSharp_loglevel ==# 'DEBUG' && lines[0] =~# '^\*\{12\}'
      " Special loglevel - DEBUG all caps. This still tells the server to pass
      " full debugging requests and responses plus debugging messages, but
      " OmniSharp-vim will not log the requests and responses - just record
      " their commands
      let prefix = matchstr(lines[0], '\*\s\+\zs\S\+\ze\%(\s(.\{-})\)\?\s\+\*')
      let num_lines = len(lines)
      let commands = filter(lines, "v:val =~# '^\\s*\"Command\":'")
      if len(commands)
        let command = matchstr(commands[0], '"Command": "\zs[^"]\+\ze"')
        let command_name = printf('Server %s: %s (%d lines)',
        \ prefix, command, num_lines - 1)
        call writefile([command_name], a:job.logfile, 'a')
      endif
    else
      let lines[0] = '        ' . lines[0]
      let prefix = s:LogLevelPrefix(a:msg.Body.LogLevel)
      call insert(lines, printf('[%s]: %s', prefix, a:msg.Body.Name))
      call writefile(lines, a:job.logfile, 'a')
    endif
  elseif get(a:msg, 'Event', '') ==# 'MsBuildProjectDiagnostics'
    if len(a:msg.Body.Errors) == 0 && len(a:msg.Body.Warnings) == 0
      return
    endif
    let lines = [a:msg.Body.FileName]
    for error in a:msg.Body.Errors
      call add(lines, printf('%s(%d,%d): Error: %s',
      \ error.FileName, error.StartLine, error.StartColumn, error.Text))
    endfor
    for warn in a:msg.Body.Warnings
      call add(lines, printf('%s(%d,%d): Warning: %s',
      \ warn.FileName, warn.StartLine, warn.StartColumn, warn.Text))
    endfor
    call writefile(lines, a:job.logfile, 'a')
  endif
endfunction

function! OmniSharp#log#Open(...) abort
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
  if cmd ==# 'edit' && !&hidden
    let cmd = 'split'
  endif
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
