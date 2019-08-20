let s:save_cpo = &cpoptions
set cpoptions&vim

let s:jobs = {}
let s:channels = {}

" Neovim jobs {{{ "

function! OmniSharp#proc#supportsNeovimJobs() abort
  return exists('*jobstart')
endfunction

function! OmniSharp#proc#neovimOutHandler(job_id, data, event) dict abort
  if g:OmniSharp_proc_debug
    echom printf('%s: %s', string(a:event), string(a:data))
  endif
  if g:OmniSharp_server_stdio
    let job = s:channels[a:job_id]

    let messages = a:data[:-2]

    if len(a:data) > 1
        let messages[0] = job.partial . messages[0]
        let job.partial = a:data[-1]
    else
        let job.partial = job.partial . a:data[0]
    endif

    for message in messages
      if message =~# "^\uFEFF"
        " Strip BOM
        let message = substitute(message, "^\uFEFF", '', '')
      endif
      call OmniSharp#stdio#HandleResponse(job, message)
    endfor
  endif
endfunction

function! OmniSharp#proc#neovimErrHandler(job_id, data, event) dict abort
  if type(a:data) == type([]) && len(a:data) && a:data[0] =~# "^\uFEFF$"
    " Ignore BOM
    return
  endif
  let message = printf('%s: %s', a:event, string(a:data))
  call OmniSharp#util#EchoErr(message)
endfunction

function! OmniSharp#proc#neovimExitHandler(job_id, data, event) dict abort
  let jobkey = ''
  for [key, val] in items(s:jobs)
    if a:job_id == val.job_id
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
  if g:OmniSharp_server_stdio || g:OmniSharp_proc_debug
    let opts['on_stdout'] = 'OmniSharp#proc#neovimOutHandler'
  endif
  let job = {
  \ 'job_id': jobstart(a:command, opts),
  \ 'partial': ''
  \}
  let s:channels[job.job_id] = job
  return job
endfunction

" }}} Neovim jobs "

" Vim jobs {{{ "

function! OmniSharp#proc#supportsVimJobs() abort
  return exists('*job_start')
endfunction

function! OmniSharp#proc#vimOutHandler(channel, message) abort
  if g:OmniSharp_proc_debug
    echom printf('%s: %s', string(a:channel), string(a:message))
  endif
  if g:OmniSharp_server_stdio
    call OmniSharp#stdio#HandleResponse(s:channels[a:channel], a:message)
  endif
endfunction

function! OmniSharp#proc#vimErrHandler(channel, message) abort
  let message = printf('%s: %s', string(a:channel), string(a:message))
  call OmniSharp#util#EchoErr(message)
endfunction

function! OmniSharp#proc#vimJobStart(command) abort
  if !OmniSharp#proc#supportsVimJobs()
    call OmniSharp#util#EchoErr('Not using Vim 8.0+')
    return -1
  endif
  call s:debug('Using vim job_start to start the following command:')
  call s:debug(a:command)
  let opts = {'err_cb': 'OmniSharp#proc#vimErrHandler'}
  if g:OmniSharp_server_stdio || g:OmniSharp_proc_debug
    let opts['out_cb'] = 'OmniSharp#proc#vimOutHandler'
  endif
  let job = {
  \ 'job_id': job_start(a:command, opts)
  \}
  let channel_id = job_getchannel(job.job_id)
  let s:channels[channel_id] = job
  return job
endfunction

" }}} Vim jobs "

" vim-dispatch {{{ "

function! OmniSharp#proc#supportsVimDispatch() abort
  return exists(':Dispatch') == 2 && !g:OmniSharp_server_stdio
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
  if g:OmniSharp_server_stdio | return 0 | endif
  let is_vimproc = 0
  silent! let is_vimproc = vimproc#version()
  return is_vimproc
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

function! OmniSharp#proc#Start(command, jobkey) abort
  if OmniSharp#proc#supportsNeovimJobs()
    let job = OmniSharp#proc#neovimJobStart(a:command)
    if job.job_id > 0
      let s:jobs[a:jobkey] = job
    else
      call OmniSharp#util#EchoErr('Command is not executable: ' . a:command[0])
    endif
  elseif OmniSharp#proc#supportsVimJobs()
    let job = OmniSharp#proc#vimJobStart(a:command)
    if job_status(job.job_id) ==# 'run'
      let s:jobs[a:jobkey] = job
    else
      call OmniSharp#util#EchoErr('Could not run command: ' . join(a:command, ' '))
    endif
  elseif OmniSharp#proc#supportsVimDispatch()
    let job = OmniSharp#proc#dispatchStart(a:command)
    let s:jobs[a:jobkey] = job
  elseif OmniSharp#proc#supportsVimProc()
    let job = OmniSharp#proc#vimprocStart(a:command)
    let s:jobs[a:jobkey] = job
  else
    call OmniSharp#util#EchoErr('Please use neovim, or vim 8.0+ or install either vim-dispatch or vimproc.vim plugin to use this feature')
  endif
  if type(job) == type({})
    let job.sln_or_dir = a:jobkey
    let job.loaded = 0
    silent doautocmd <nomodeline> User OmniSharpStarted
  endif
  return job
endfunction

function! OmniSharp#proc#StopJob(jobkey) abort
  if !OmniSharp#proc#IsJobRunning(a:jobkey)
    return
  endif
  let job = s:jobs[a:jobkey]

  if OmniSharp#proc#supportsNeovimJobs()
    call jobstop(job.job_id)
  elseif OmniSharp#proc#supportsVimJobs()
    call job_stop(job.job_id)
  elseif OmniSharp#proc#supportsVimDispatch()
    call dispatch#abort_command(0, job.command)
  elseif OmniSharp#proc#supportsVimProc()
    call job.kill()
  endif
  if has_key(s:jobs, a:jobkey)
    call remove(s:jobs, a:jobkey)
  endif
  silent doautocmd <nomodeline> User OmniSharpStopped
endfunction

function! OmniSharp#proc#ListRunningJobs() abort
  return filter(keys(s:jobs), 'OmniSharp#proc#IsJobRunning(v:val)')
endfunction

function! OmniSharp#proc#IsJobRunning(jobkey) abort
  " Either a jobkey (sln_or_dir) or a job may be passed in
  if type(a:jobkey) == type({})
    let job = a:jobkey
  else
    if !has_key(s:jobs, a:jobkey)
      return 0
    endif
    let job = get(s:jobs, a:jobkey)
  endif
  if OmniSharp#proc#supportsNeovimJobs()
    return 1
  elseif OmniSharp#proc#supportsVimJobs()
    let status = job_status(job.job_id)
    return status ==# 'run'
  elseif OmniSharp#proc#supportsVimDispatch()
    return dispatch#completed(job)
  elseif OmniSharp#proc#supportsVimProc()
    let [cond, status] = job.checkpid()
    return status != 0
  endif
endfunction

function! OmniSharp#proc#GetJob(jobkey) abort
  return get(s:jobs, a:jobkey, '')
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
