let s:save_cpo = &cpoptions
set cpoptions&vim

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
  endif
  let completions = OmniSharp#py#eval(
  \ printf('getCompletions(%s)', string(a:partial)))
  if OmniSharp#CheckPyError() | let completions = [] | endif
  return s:CBGet(opts, completions)
endfunction

function! s:StdioGetCompletions(partial, Callback) abort
  " TODO: Specific option to disable rich documentation in popups
  let wantDocPopup = OmniSharp#PreferPopups()
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
    else
      let word = cmp.CompletionText != v:null ? cmp.CompletionText : cmp.MethodHeader
      let menu = (cmp.ReturnType != v:null ? cmp.ReturnType . ' ' : '') .
      \ (cmp.DisplayText != v:null ? cmp.DisplayText : cmp.MethodHeader)
    endif
    let completion = {
    \ 'snip': get(cmp, 'Snippet', ''),
    \ 'word': word,
    \ 'menu': menu,
    \ 'icase': 1,
    \ 'dup': 1
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
      autocmd CompleteChanged <buffer> call s:GetDocumentation()
    augroup END
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(a:completions)
  else
    return a:completions
  endif
endfunction

function! s:GetDocumentation() abort
  if !has_key(v:event.completed_item, 'info')
  \ || len(v:event.completed_item.info) == 0
    return
  endif
  let method = split(v:event.completed_item.info, "\n")[0]
  let id = popup_findinfo()
  if id
    if method =~# '('
      call OmniSharp#actions#signature#SignatureHelp({
      \ 'winid': id,
      \ 'ForCompleteMethod': method
      \})
    else
      call OmniSharp#actions#documentation#Documentation({ 'winid': id })
    endif
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
