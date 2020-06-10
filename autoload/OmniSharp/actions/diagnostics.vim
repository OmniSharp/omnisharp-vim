let s:save_cpo = &cpoptions
set cpoptions&vim

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the results
function! OmniSharp#actions#diagnostics#Check(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return [] | endif
  if pumvisible() || !OmniSharp#IsServerRunning()
    let b:codecheck = get(b:, 'codecheck', [])
    if has_key(opts, 'Callback')
      call opts.Callback(b:codecheck)
    endif
    return b:codecheck
  endif
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBCodeCheck', [opts])
    call OmniSharp#actions#diagnostics#StdioCheck({}, Callback)
  else
    let codecheck = OmniSharp#py#eval('codeCheck()')
    if OmniSharp#CheckPyError() | return | endif
    return s:CBCodeCheck(opts, codecheck)
  endif
endfunction

function! OmniSharp#actions#diagnostics#CheckGlobal(...) abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return [] | endif
  " Place the results in the quickfix window, if possible
  if g:OmniSharp_server_stdio
    call s:StdioCheckGlobal(function('s:CBGlobalCodeCheck'))
  else
    let quickfixes = OmniSharp#py#eval('globalCodeCheck()')
    if OmniSharp#CheckPyError() | return | endif
    call s:CBGlobalCodeCheck(quickfixes)
  endif
endfunction

" Normally this function would be named 's:StdioCheck`, but it is accessed
" directly from autoload/ale/sources/OmniSharp.vim so requires a full autoload
" function name.
function! OmniSharp#actions#diagnostics#StdioCheck(opts, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioCheckRH', [a:Callback]),
  \ 'ReplayOnLoad': 1
  \}
  call extend(opts, a:opts, 'force')
  call OmniSharp#stdio#Request('/codecheck', opts)
endfunction

function! s:StdioCheckGlobal(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioCheckRH', [a:Callback])
  \}
  call OmniSharp#stdio#RequestSend({}, '/codecheck', opts)
endfunction

function! s:StdioCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse(a:response.Body.QuickFixes))
endfunction

function! s:CBCodeCheck(opts, codecheck) abort
  let b:codecheck = a:codecheck
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(a:codecheck)
  endif
  return b:codecheck
endfunction

function! s:CBGlobalCodeCheck(quickfixes) abort
  if len(a:quickfixes) > 0
    call OmniSharp#locations#SetQuickfix(a:quickfixes, 'Code Check Messages')
  else
    echo 'No Code Check messages'
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2