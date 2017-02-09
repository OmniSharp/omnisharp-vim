let s:save_cpo = &cpo
set cpo&vim

let g:omnisharp_proc_debug = 0

function! s:debug(message)
  if g:omnisharp_proc_debug == 1
    echom "DEBUG: " . string(a:message)
  endif
endfunction

function! OmniSharp#proc#supportsNeovimJobs() abort
  return exists('*jobstart')
endfunction

function! OmniSharp#proc#neovimOutHandler(job_id, data, event)
  if g:omnisharp_proc_debug == 1
    echom printf('%s: %s',a:event,string(a:data))
  endif
endfunction

function! OmniSharp#proc#neovimErrHandler(job_id, data, event)
  echoerr printf('%s: %s',a:event,string(a:data))
endfunction

function! OmniSharp#proc#neovimJobstart(command) abort
  if OmniSharp#proc#supportsNeovimJobs()
    call s:debug("Using Neovim jobstart to start the following command:")
    call s:debug(a:command)
    return jobstart(
                \ a:command,
                \ {'on_stdout': 'OmniSharp#proc#neovimOutHandler',
                \  'on_stderr': 'OmniSharp#proc#neovimErrHandler'})
  else
    echoerr 'Not using neovim'
  endif
endfunction

function! OmniSharp#proc#supportsVimJobs() abort
  return exists('*job_start')
endfunction

function! OmniSharp#proc#vimOutHandler(channel, message)
  if g:omnisharp_proc_debug == 1
      echom printf('%s: %s', string(a:channel), string(a:message))
  endif
endfunction

function! OmniSharp#proc#vimErrHandler(channel, message)
  echoerr printf('%s: %s', string(a:channel), string(a:message))
endfunction

function! OmniSharp#proc#vimJobstart(command) abort
  if OmniSharp#proc#supportsVimJobs()
    call s:debug("Using vim job_start to start the following command:")
    call s:debug(a:command)
    return job_start(
                \ a:command,
                \ {'out_cb': 'OmniSharp#proc#vimOutHandler',
                \  'err_cb': 'OmniSharp#proc#vimErrHandler'})
  else
    echoerr 'Not using Vim 8.0+'
  endif
endfunction

function! OmniSharp#proc#supportsVimDispatch() abort
  return exists(':Dispatch') == 2
endfunction

function! OmniSharp#proc#dispatch(command) abort
  if OmniSharp#proc#supportsVimDispatch()
    call dispatch#start(join(a:command, ' '), {'background': 1})
  else
    echoerr 'vim-dispatch not found'
  endif
endfunction

function! OmniSharp#proc#supportsVimProc() abort
  let is_vimproc = 0
  silent! let is_vimproc = vimproc#version()
  return is_vimproc
endfunction

function! OmniSharp#proc#vimprocStart(command) abort
  if OmniSharp#proc#supportsVimProc()
    " FIXME: consider using vimproc#popen3 as it gives control over the
    " process and we can get the stdout/stderr separately
    " FIXME: Should we be still replacing the path separator?
    call vimproc#system_bg(substitute(join(a:command, ' '), '\\', '\/', 'g'))
  else
    echoerr 'vimproc not found'
  endif
endfunction

function! OmniSharp#proc#RunAsyncCommand(command) abort
  if OmniSharp#proc#supportsNeovimJobs()
    call OmniSharp#proc#neovimJobstart(a:command)
  elseif OmniSharp#proc#supportsVimJobs()
    call OmniSharp#proc#vimJobstart(a:command)
  elseif OmniSharp#proc#supportsVimDispatch()
    call OmniSharp#proc#dispatch(a:command)
  elseif OmniSharp#proc#supportsVimProc()
    call OmniSharp#proc#vimprocStart(a:command)
  else
    echoerr 'Please use neovim, or vim 8.0+ or install either vim-dispatch or vimproc plugin to use this feature'
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
