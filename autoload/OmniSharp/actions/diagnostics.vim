let s:save_cpo = &cpoptions
set cpoptions&vim

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the results
function! OmniSharp#actions#diagnostics#Check(...) abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return [] | endif
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
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

" Find all solution/project diagnostics and populate the quickfix list.
" Optional argument:
" Callback: When a callback is passed in, the diagnostics will be sent to
"           the callback *instead of* to the quickfix list.
function! OmniSharp#actions#diagnostics#CheckGlobal(...) abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return [] | endif
  if a:0 && a:1 isnot 0
    let Callback = a:1
  else
    let Callback = function('s:CBGlobalCodeCheck')
  endif
  if g:OmniSharp_server_stdio
    let opts = {
    \ 'ResponseHandler': function('s:StdioCheckRH', [Callback])
    \}
    let job = OmniSharp#GetHost().job
    call OmniSharp#stdio#RequestGlobal(job, '/codecheck', opts)
  else
    let quickfixes = OmniSharp#py#Eval('globalCodeCheck()')
    if OmniSharp#py#CheckForError() | return | endif
    call Callback(quickfixes)
  endif
endfunction

" Normally this function would be named 's:StdioCheck`, but it is accessed
" directly from autoload/ale/sources/OmniSharp.vim so requires a full autoload
" function name.
function! OmniSharp#actions#diagnostics#StdioCheck(bufnr, Callback) abort
  " OmniSharp#actions#buffer#Update only updates the server state when the
  " buffer has been modified since the last server update
  call OmniSharp#actions#buffer#Update()
  let opts = {
  \ 'ResponseHandler': function('s:StdioCheckRH', [a:Callback]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0,
  \ 'ReplayOnLoad': 1
  \}
  call OmniSharp#stdio#Request('/codecheck', opts)
endfunction

function! s:StdioCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  let quickfixes = a:response.Body.QuickFixes
  call a:Callback(OmniSharp#actions#diagnostics#Parse(quickfixes))
endfunction

function! OmniSharp#actions#diagnostics#Parse(quickfixes) abort
  let locations = []
  for quickfix in a:quickfixes

    let exclude_paths = get(g:, 'OmniSharp_diagnostic_exclude_paths', [])
    if len(exclude_paths) && has_key(quickfix, 'FileName')
      let exclude = 0
      for exclude_path in exclude_paths
        if match(quickfix.FileName, exclude_path) > 0
          let exclude = 1
          break
        endif
      endfor
      if exclude
        continue
      endif
    endif

    let overrides = get(g:, 'OmniSharp_diagnostic_overrides', {})
    let diag_id = get(quickfix, 'Id', '-')
    if diag_id =~# '.FadeOut$'
      " The `FadeOut` analyzers are a VSCode feature and not usable by Vim.
      " These diagnostics are always sent as duplicates so just ignore the
      " FadeOut diagnostic.
      continue
    elseif index(keys(overrides), diag_id) >= 0
      if overrides[diag_id].type ==? 'None'
        continue
      endif
      call extend(quickfix, overrides[diag_id])
    endif

    let text = get(quickfix, 'Text', get(quickfix, 'Message', ''))
    if get(g:, 'OmniSharp_diagnostic_showid') && has_key(quickfix, 'Id')
      let text = quickfix.Id . ': ' . text
    endif
    let location = {
    \ 'filename': has_key(quickfix, 'FileName')
    \   ? OmniSharp#util#TranslatePathForClient(quickfix.FileName)
    \   : expand('%:p'),
    \ 'text': text,
    \ 'lnum': quickfix.Line,
    \ 'col': quickfix.Column,
    \ 'vcol': 1
    \}
    if has_key(quickfix, 'EndLine') && has_key(quickfix, 'EndColumn')
      let location.end_lnum = quickfix.EndLine
      let location.end_col = quickfix.EndColumn - 1
    endif

    if has_key(quickfix, 'type')
      let location.type = get(quickfix, 'type')
      if has_key(quickfix, 'subtype')
        let location.subtype = get(quickfix, 'subtype')
      endif
    else
      let loglevel = get(quickfix, 'LogLevel', '')
      if loglevel !=# ''
        if loglevel ==# 'Error'
          let location.type = 'E'
        elseif loglevel ==# 'Info'
          let location.type = 'I'
        else
          let location.type = 'W'
        endif
        if loglevel ==# 'Hidden'
          let location.subtype = 'Style'
        endif
      endif
    endif

    call add(locations, location)
  endfor
  return locations
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
