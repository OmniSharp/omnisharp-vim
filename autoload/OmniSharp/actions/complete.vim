let s:save_cpo = &cpoptions
set cpoptions&vim

let s:generated_snippets = get(s:, 'generated_snippets', {})
let s:last_completion_dictionary = get(s:, 'last_completion_dictionary', {})

function! OmniSharp#actions#complete#Get(partial, ...) abort
  let opts = a:0 ? { 'Callback': a:1 } : {}
  if !OmniSharp#IsServerRunning()
    return []
  endif
  if g:OmniSharp_server_stdio
    let s:complete_pending = 1
    call s:StdioGetCompletions(a:partial, function('s:CBGet', [opts]))
    if !has_key(opts, 'Callback')
      " No callback has been passed in, so this function should return
      " synchronously, so it can be used as an omnifunc
      let starttime = reltime()
      while s:complete_pending && reltime(starttime)[0] < g:OmniSharp_timeout
        sleep 50m
      endwhile
      if s:complete_pending | return [] | endif
      return s:last_completions
    endif
    return []
  else
    let completions = OmniSharp#py#Eval(
    \ printf('getCompletions(%s)', string(a:partial)))
    if OmniSharp#py#CheckForError() | let completions = [] | endif
    return s:CBGet(opts, completions)
  endif
endfunction

function! OmniSharp#actions#complete#ExpandSnippet() abort
  if !g:OmniSharp_want_snippet
    return
  endif

  if empty(globpath(&runtimepath, 'plugin/UltiSnips.vim'))
    call OmniSharp#util#EchoErr('g:OmniSharp_want_snippet is enabled but this requires the UltiSnips plugin and it is not installed.')
    return
  endif

  let line = strpart(getline('.'), 0, col('.')-1)
  let remove_whitespace_regex = '^\s*\(.\{-}\)\s*$'

  let completion = matchstr(line, '.*\zs\s\W.\+(.*)')
  let completion = substitute(completion, remove_whitespace_regex, '\1', '')

  let should_expand_completion = len(completion) != 0

  if should_expand_completion
    let completion = split(completion, '\.')[-1]
    let completion = split(completion, 'new ')[-1]
    let completion = split(completion, '= ')[-1]

    if has_key(s:last_completion_dictionary, completion)
      let snippet = get(get(s:last_completion_dictionary, completion, ''), 'snip','')
      if !has_key(s:generated_snippets, completion)
        call UltiSnips#AddSnippetWithPriority(completion, snippet, completion, 'iw', 'cs', 1)
        let s:generated_snippets[completion] = snippet
      endif
      call UltiSnips#CursorMoved()
      call UltiSnips#ExpandSnippetOrJump()
    endif
  endif
endfunction


function! s:StdioGetCompletions(partial, Callback) abort
  let wantDocPopup = OmniSharp#popup#Enabled()
  \ && g:omnicomplete_fetch_full_documentation
  \ && &completeopt =~# 'popup'
  let wantDoc = wantDocPopup ? 'false'
  \ : g:omnicomplete_fetch_full_documentation ? 'true' : 'false'
  let wantSnippet = g:OmniSharp_want_snippet ? 'true' : 'false'
  let parameters = {
  \ 'WordToComplete': a:partial,
  \ 'WantDocumentationForEveryCompletionResult': wantDoc,
  \ 'WantSnippet': wantSnippet,
  \ 'WantMethodHeader': 'true',
  \ 'WantReturnType': 'true'
  \}
  let opts = {
  \ 'ResponseHandler': function('s:StdioGetCompletionsRH', [a:Callback, wantDocPopup]),
  \ 'Parameters': parameters
  \}
  call OmniSharp#stdio#Request('/autocomplete', opts)
endfunction

function! s:StdioGetCompletionsRH(Callback, wantDocPopup, response) abort
  if !a:response.Success | return | endif
  let completions = []
  for cmp in a:response.Body
    if g:OmniSharp_want_snippet
      let word = cmp.MethodHeader != v:null ? cmp.MethodHeader : cmp.CompletionText
      let menu = cmp.ReturnType != v:null ? cmp.ReturnType : cmp.DisplayText
    elseif g:OmniSharp_completion_without_overloads
      let word = cmp.CompletionText
      let menu = ''
    else
      let word = cmp.CompletionText != v:null ? cmp.CompletionText : cmp.MethodHeader
      let menu = (cmp.ReturnType != v:null ? cmp.ReturnType . ' ' : '') .
      \ (cmp.DisplayText != v:null ? cmp.DisplayText : cmp.MethodHeader)
    endif
    if word == v:null
      continue
    endif
    let completion = {
    \ 'snip': get(cmp, 'Snippet', ''),
    \ 'word': word,
    \ 'menu': menu,
    \ 'icase': 1,
    \ 'dup': g:OmniSharp_completion_without_overloads ? 0 : 1
    \}
    if a:wantDocPopup
      let completion.info = cmp.MethodHeader . "\n ..."
    elseif g:omnicomplete_fetch_full_documentation
      let completion.info = ' '
      if has_key(cmp, 'Description') && cmp.Description != v:null
        let completion.info = cmp.Description
      endif
    endif
    call add(completions, completion)
  endfor
  call a:Callback(completions, a:wantDocPopup)
endfunction

function! s:CBGet(opts, completions, ...) abort
  let s:last_completions = a:completions
  let s:complete_pending = 0
  let s:last_completion_dictionary = {}
  for completion in a:completions
    let s:last_completion_dictionary[get(completion, 'word')] = completion
  endfor
  if a:0 && a:1
    " wantDocPopup
    augroup OmniSharp_CompletePopup
      autocmd!
      autocmd CompleteChanged <buffer> call s:GetDocumentationDelayed()
    augroup END
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(a:completions)
  else
    return a:completions
  endif
endfunction

function! s:GetDocumentationDelayed() abort
  " Debounce documentation requests, preventing Vim from slowing down while
  " CTRL-N'ing through completion results
  if exists('s:docTimer')
    call timer_stop(s:docTimer)
  endif
  if !has_key(v:event.completed_item, 'info')
  \ || len(v:event.completed_item.info) == 0
    return
  endif
  let s:docTimer = timer_start(get(g:, 'OmniSharpCompletionDocDebounce', 200),
  \ function('s:GetDocumentation', [v:event.completed_item]))
endfunction

function! s:GetDocumentation(completed_item, timer) abort
  let info = split(a:completed_item.info, "\n")[0]
  let id = popup_findinfo()
  if id
    if info =~# '('
      call OmniSharp#actions#signature#SignatureHelp({
      \ 'winid': id,
      \ 'ForCompleteMethod': info
      \})
    else
      call OmniSharp#actions#documentation#Documentation({
      \ 'winid': id,
      \ 'ForCompletion': info
      \})
    endif
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
