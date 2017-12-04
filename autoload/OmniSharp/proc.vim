let s:save_cpo = &cpoptions
set cpoptions&vim

let g:omnisharp_proc_debug = get(g:, 'omnisharp_proc_debug', 0)

function! s:debug(message) abort
  if g:omnisharp_proc_debug == 1
    echom 'DEBUG: ' . string(a:message)
  endif
endfunction

function! OmniSharp#proc#supportsNeovimJobs() abort
  return exists('*jobstart')
endfunction

function! OmniSharp#proc#neovimOutHandler(job_id, data, event) abort
  if g:omnisharp_proc_debug == 1
    let l:message = printf('%s: %s',a:event,string(a:data))
    echom l:message
  endif
endfunction

function! OmniSharp#proc#neovimErrHandler(job_id, data, event) abort
  let l:message = printf('%s: %s',a:event,string(a:data))
  echoerr l:message
endfunction

function! OmniSharp#proc#neovimJobStart(command) abort
  if OmniSharp#proc#supportsNeovimJobs()
    call s:debug('Using Neovim jobstart to start the following command:')
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

function! OmniSharp#proc#vimOutHandler(channel, message) abort
  if g:omnisharp_proc_debug == 1
      echom printf('%s: %s', string(a:channel), string(a:message))
  endif
endfunction

function! OmniSharp#proc#vimErrHandler(channel, message) abort
  echoerr printf('%s: %s', string(a:channel), string(a:message))
endfunction

function! OmniSharp#proc#vimJobStart(command) abort
  if OmniSharp#proc#supportsVimJobs()
    call s:debug('Using vim job_start to start the following command:')
    call s:debug(a:command)
    if !exists('s:job') || job_status(s:job) ==# 'dead'
      let s:job = job_start(
                  \ a:command,
                  \ {'out_cb': 'OmniSharp#proc#vimOutHandler',
                  \  'err_cb': 'OmniSharp#proc#vimErrHandler'})
    else
      call s:debug('Skip to start server since job still exists')
    endif
  else
    echoerr 'Not using Vim 8.0+'
  endif
endfunction

function! OmniSharp#proc#supportsVimDispatch() abort
  return exists(':Dispatch') == 2
endfunction

function! OmniSharp#proc#dispatchStart(command) abort
  if OmniSharp#proc#supportsVimDispatch()
    return dispatch#spawn(
          \ call('dispatch#shellescape', a:command),
          \ {'background': 1})
  else
    echoerr 'vim-dispatch not found'
  endif
endfunction

function! OmniSharp#proc#supportsVimProc() abort
  let l:is_vimproc = 0
  silent! let l:is_vimproc = vimproc#version()
  return l:is_vimproc
endfunction

function! OmniSharp#proc#vimprocStart(command) abort
  if OmniSharp#proc#supportsVimProc()
    return vimproc#popen3(a:command)
  else
    echoerr 'vimproc not found'
  endif
endfunction

function! OmniSharp#proc#RunAsyncCommand(command) abort
  if OmniSharp#proc#supportsNeovimJobs()
    call OmniSharp#proc#neovimJobStart(a:command)
  elseif OmniSharp#proc#supportsVimJobs()
    call OmniSharp#proc#vimJobStart(a:command)
  elseif OmniSharp#proc#supportsVimDispatch()
    call OmniSharp#proc#dispatchStart(a:command)
  elseif OmniSharp#proc#supportsVimProc()
    call OmniSharp#proc#vimprocStart(a:command)
  else
    echoerr 'Please use neovim, or vim 8.0+ or install either vim-dispatch or vimproc.vim plugin to use this feature'
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: shiftwidth=2
