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
    call OmniSharp#actions#diagnostics#StdioCheck(bufnr('%'), Callback)
  else
    let codecheck = OmniSharp#py#Eval('codeCheck()')
    if OmniSharp#py#CheckForError() | return | endif
    return s:CBCodeCheck(opts, codecheck)
  endif
endfunction

function! OmniSharp#actions#diagnostics#CheckGlobal(...) abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return [] | endif
  " Place the results in the quickfix window, if possible
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBGlobalCodeCheck')
    let opts = {
    \ 'ResponseHandler': function('s:StdioCheckRH', [Callback])
    \}
    let job = OmniSharp#GetHost().job
    call OmniSharp#stdio#RequestGlobal(job, '/codecheck', opts)
  else
    let quickfixes = OmniSharp#py#Eval('globalCodeCheck()')
    if OmniSharp#py#CheckForError() | return | endif
    call s:CBGlobalCodeCheck(quickfixes)
  endif
endfunction

" Normally this function would be named 's:StdioCheck`, but it is accessed
" directly from autoload/ale/sources/OmniSharp.vim so requires a full autoload
" function name.
function! OmniSharp#actions#diagnostics#StdioCheck(bufnr, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioCheckRH', [a:Callback]),
  \ 'BufNum': a:bufnr,
  \ 'ReplayOnLoad': 1
  \}
  call OmniSharp#stdio#Request('/codecheck', opts)
endfunction

function! s:StdioCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse(a:response.Body.QuickFixes,
  \ function('s:DiagnosticQuickfixFixup')))
endfunction

function! s:DiagnosticQuickfixFixup(quickfix) abort
  let exclude_paths = get(g:, 'OmniSharp_diagnostic_exclude_paths', [])
  if len(exclude_paths) && has_key(a:quickfix, 'FileName')
    for exclude_path in exclude_paths
      if match(a:quickfix.FileName, exclude_path) > 0
        return {}
      endif
    endfor
  endif

  let overrides = get(g:, 'OmniSharp_diagnostic_overrides', {})
  let diag_id = get(a:quickfix, 'Id', '-')
  if diag_id =~# '.FadeOut$'
    " Some analyzers such as roslynator provide 2 diagnostics: one to mark
    " the start of the issue location and another to mark the end, e.g.
    " `RCS1124FadeOut`. We never make use of these FadeOut diagnostics, as
    " we can extract start and end locations from the main diagnostic.
    return {}
  elseif index(keys(overrides), diag_id) >= 0
    if overrides[diag_id].type ==? 'None'
      return {}
    endif
    call extend(a:quickfix, overrides[diag_id])
  endif

  if get(g:, 'OmniSharp_diagnostic_showid') && has_key(a:quickfix, 'Id')
    if has_key(a:quickfix, 'Text')
      let a:quickfix.Text = a:quickfix.Id . ': ' .a:quickfix.Text
    elseif has_key(a:quickfix, 'Message')
      let a:quickfix.Message = a:quickfix.Id . ': ' . a:quickfix.Message
    endif
  endif

  return a:quickfix
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
