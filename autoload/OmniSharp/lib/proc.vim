let s:save_cpo = &cpo
set cpo&vim

let g:omnisharp_proc_debug = 0

function! s:debug(message)
  if g:omnisharp_proc_debug == 1
    echom "DEBUG: " . string(a:message)
  endif
endfunction

function! OmniSharp#lib#proc#supportsNeovimJobs() abort
  return exists('*jobstart')
endfunction

function! OmniSharp#lib#proc#neovimOutHandler(job_id, data, event)
  if g:omnisharp_proc_debug == 1
    echom printf('%s: %s',a:event,string(a:data))
  endif
endfunction

function! OmniSharp#lib#proc#neovimErrHandler(job_id, data, event)
  echoerr printf('%s: %s',a:event,string(a:data))
endfunction

function! OmniSharp#lib#proc#neovimJobstart(command) abort
  if OmniSharp#lib#proc#supportsNeovimJobs()
    call s:debug("Using Neovim jobstart to start the following command:")
    call s:debug(a:command)
    return jobstart(
                \ a:command,
                \ {'on_stdout': 'OmniSharp#lib#proc#neovimOutHandler',
                \  'on_stderr': 'OmniSharp#lib#proc#neovimErrHandler'})
  else
    echoerr 'Not using neovim'
  endif
endfunction

function! OmniSharp#lib#proc#supportsVimJobs() abort
  return exists('*job_start')
endfunction

function! OmniSharp#lib#proc#vimOutHandler(channel, message)
  if g:omnisharp_proc_debug == 1
      echom printf('%s: %s', string(a:channel), string(a:message))
  endif
endfunction

function! OmniSharp#lib#proc#vimErrHandler(channel, message)
  echoerr printf('%s: %s', string(a:channel), string(a:message))
endfunction

function! OmniSharp#lib#proc#vimJobstart(command) abort
  if OmniSharp#lib#proc#supportsVimJobs()
    call s:debug("Using vim job_start to start the following command:")
    call s:debug(a:command)
    return job_start(
                \ a:command,
                \ {'out_cb': 'OmniSharp#lib#proc#vimOutHandler',
                \  'err_cb': 'OmniSharp#lib#proc#vimErrHandler'})
  else
    echoerr 'Not using Vim 8.0+'
  endif
endfunction

function! OmniSharp#lib#proc#supportsVimDispatch() abort
  return exists(':Dispatch') == 2
endfunction

function! OmniSharp#lib#proc#dispatch(command) abort
  if OmniSharp#lib#proc#supportsVimDispatch()
    call dispatch#start(join(a:command, ' '), {'background': 1})
  else
    echoerr 'vim-dispatch not found'
  endif
endfunction

function! OmniSharp#lib#proc#supportsVimProc() abort
  let is_vimproc = 0
  silent! let is_vimproc = vimproc#version()
  return is_vimproc
endfunction

function! OmniSharp#lib#proc#vimprocStart(command) abort
  if OmniSharp#lib#proc#supportsVimProc()
    " FIXME: consider using vimproc#popen3 as it gives control over the
    " process and we can get the stdout/stderr separately
    call vimproc#system_bg(substitute(join(a:command, ' '), '\\', '\/', 'g'))
  else
    echoerr 'vimproc not found'
  endif
endfunction

function! OmniSharp#lib#proc#RunAsyncCommand(command) abort
  if OmniSharp#lib#proc#supportsNeovimJobs()
    call OmniSharp#lib#proc#neovimJobstart(a:command)
  elseif OmniSharp#lib#proc#supportsVimJobs()
    call OmniSharp#lib#proc#vimJobstart(a:command)
  elseif OmniSharp#lib#proc#supportsVimDispatch()
    call OmniSharp#lib#proc#dispatch(a:command)
  elseif OmniSharp#lib#proc#supportsVimProc()
    call OmniSharp#lib#proc#vimprocStart(a:command)
  else
    echoerr 'Please use neovim, or vim 8.0+ or install either vim-dispatch or vimproc plugin to use this feature'
  endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
