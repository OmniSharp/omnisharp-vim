let s:save_cpo = &cpoptions
set cpoptions&vim

let s:jobs = {}

" Neovim jobs {{{ "

function! OmniSharp#proc#supportsNeovimJobs() abort
  return exists('*jobstart')
endfunction

function! OmniSharp#proc#neovimOutHandler(job_id, data, event) dict abort
  let l:message = printf('%s: %s',a:event,string(a:data))
  echom l:message
endfunction

function! OmniSharp#proc#neovimErrHandler(job_id, data, event) dict abort
  let l:message = printf('%s: %s',a:event,string(a:data))
  call OmniSharp#util#EchoErr(l:message)
endfunction

function! OmniSharp#proc#neovimExitHandler(job_id, data, event) dict abort
  let jobkey = ''
  for [key, id] in items(s:jobs)
    if a:job_id == id
      let jobkey = key
      break
    endif
  endfor
  if !empty(jobkey) && has_key(s:jobs, jobkey)
    call remove(s:jobs, jobkey)
  endif
endfunction

function! OmniSharp#proc#neovimJobStart(command) abort
  if !OmniSharp#proc#supportsNeovimJobs()
    call OmniSharp#util#EchoErr('Not using neovim')
    return -1
  endif
  call s:debug('Using Neovim jobstart to start the following command:')
  call s:debug(a:command)
  let opts = {'on_stderr': 'OmniSharp#proc#neovimErrHandler',
             \  'on_exit': 'OmniSharp#proc#neovimExitHandler'}
  if g:OmniSharp_proc_debug
    let opts['on_stdout'] = 'OmniSharp#proc#neovimOutHandler'
  endif
  return jobstart(a:command, opts)
endfunction

" }}} Neovim jobs "

" Vim jobs {{{ "

function! OmniSharp#proc#supportsVimJobs() abort
  return exists('*job_start')
endfunction

function! OmniSharp#proc#vimOutHandler(channel, message) abort
  echom printf('%s: %s', string(a:channel), string(a:message))
endfunction

function! OmniSharp#proc#vimErrHandler(channel, message) abort
  let l:message = printf('%s: %s', string(a:channel), string(a:message))
  call OmniSharp#util#EchoErr(l:message)
endfunction

function! OmniSharp#proc#vimJobStart(command) abort
  if !OmniSharp#proc#supportsVimJobs()
    call OmniSharp#util#EchoErr('Not using Vim 8.0+')
    return -1
  endif
  call s:debug('Using vim job_start to start the following command:')
  call s:debug(a:command)
  let opts = {'err_cb': 'OmniSharp#proc#vimErrHandler'}
  if g:OmniSharp_proc_debug
    let opts['out_cb'] = 'OmniSharp#proc#vimOutHandler'
  endif
  return job_start(a:command, opts)
endfunction

" }}} Vim jobs "

" vim-dispatch {{{ "

function! OmniSharp#proc#supportsVimDispatch() abort
  return exists(':Dispatch') == 2
endfunction

function! OmniSharp#proc#dispatchStart(command) abort
  if OmniSharp#proc#supportsVimDispatch()
    return dispatch#spawn(
          \ call('dispatch#shellescape', a:command),
          \ {'background': 1})
  else
    call OmniSharp#util#EchoErr('vim-dispatch not found')
    return -1
  endif
endfunction

" }}} vim-dispatch "

" vim-proc {{{ "

function! OmniSharp#proc#supportsVimProc() abort
  let l:is_vimproc = 0
  silent! let l:is_vimproc = vimproc#version()
  return l:is_vimproc
endfunction

function! OmniSharp#proc#vimprocStart(command) abort
  if OmniSharp#proc#supportsVimProc()
    return vimproc#popen3(a:command)
  else
    call OmniSharp#util#EchoErr('vimproc not found')
    return -1
  endif
endfunction

" }}} vim-proc "

" public functions {{{ "

function! OmniSharp#proc#RunAsyncCommand(command, jobkey) abort
  if OmniSharp#proc#IsJobRunning(a:jobkey)
    return
  endif
  if OmniSharp#proc#supportsNeovimJobs()
    let job_id = OmniSharp#proc#neovimJobStart(a:command)
    if job_id > 0
      let s:jobs[a:jobkey] = job_id
    else
      call OmniSharp#util#EchoErr('command is not executable: ' . a:command[0])
    endif
  elseif OmniSharp#proc#supportsVimJobs()
    let job_id = OmniSharp#proc#vimJobStart(a:command)
    if job_status(job_id) ==# 'run'
      let s:jobs[a:jobkey] = job_id
    else
      call OmniSharp#util#EchoErr('could not run command: ' . join(a:command, ' '))
    endif
  elseif OmniSharp#proc#supportsVimDispatch()
    let req = OmniSharp#proc#dispatchStart(a:command)
    let s:jobs[a:jobkey] = req
  elseif OmniSharp#proc#supportsVimProc()
    let proc = OmniSharp#proc#vimprocStart(a:command)
    let s:jobs[a:jobkey] = proc
  else
    call OmniSharp#util#EchoErr('Please use neovim, or vim 8.0+ or install either vim-dispatch or vimproc.vim plugin to use this feature')
  endif
endfunction

function! OmniSharp#proc#StopJob(jobkey) abort
  if !OmniSharp#proc#IsJobRunning(a:jobkey)
    return
  endif
  let job_id = s:jobs[a:jobkey]

  if OmniSharp#proc#supportsNeovimJobs()
    call jobstop(job_id)
  elseif OmniSharp#proc#supportsVimJobs()
    call job_stop(job_id)
  elseif OmniSharp#proc#supportsVimDispatch()
    call dispatch#abort_command(0, job_id.command)
  elseif OmniSharp#proc#supportsVimProc()
    call job_id.kill()
  endif
  if has_key(s:jobs, a:jobkey)
    call remove(s:jobs, a:jobkey)
  endif
endfunction

function! OmniSharp#proc#ListRunningJobs() abort
  return filter(keys(s:jobs), 'OmniSharp#proc#IsJobRunning(v:val)')
endfunction

function! OmniSharp#proc#IsJobRunning(jobkey) abort
  if !has_key(s:jobs, a:jobkey)
    return 0
  endif
  let job_id = get(s:jobs, a:jobkey)
  if OmniSharp#proc#supportsNeovimJobs()
    return 1
  elseif OmniSharp#proc#supportsVimJobs()
    let status = job_status(job_id)
    return status ==# 'run'
  elseif OmniSharp#proc#supportsVimDispatch()
    return dispatch#completed(job_id)
  elseif OmniSharp#proc#supportsVimProc()
    let [cond, status] = job_id.checkpid()
    return status != 0
  endif
endfunction

" }}} public functions "

" private functions {{{ "

function! s:debug(message) abort
  if g:OmniSharp_proc_debug == 1
    echom 'DEBUG: ' . string(a:message)
  endif
endfunction

" }}} private functions "

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
