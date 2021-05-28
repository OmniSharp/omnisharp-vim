if !OmniSharp#util#CheckCapabilities() | finish | endif

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:format_line(quickfix) abort
  return printf('%s: %d col %d     %s',
  \ a:quickfix.filename, a:quickfix.lnum, a:quickfix.col, a:quickfix.text)
endfunction

function! s:location_sink(str) abort
  for quickfix in s:quickfixes
    if s:format_line(quickfix) == a:str
      break
    endif
  endfor
  echo quickfix.filename
  call OmniSharp#locations#Navigate(quickfix)
endfunction

function! fzf#OmniSharp#FindSymbols(quickfixes) abort
  let s:quickfixes = a:quickfixes
  let symbols = []
  for quickfix in s:quickfixes
    call add(symbols, s:format_line(quickfix))
  endfor
  let fzf_options = copy(get(g:, 'OmniSharp_fzf_options', { 'down': '40%' }))
  call fzf#run(
  \ extend(fzf_options, {
  \ 'source': symbols,
  \ 'sink': function('s:location_sink')}))
endfunction

function! s:action_sink(str) abort
  if s:match_on_prefix
    let index = str2nr(a:str[0: stridx(a:str, ':') - 1])
    let action = s:actions[index]
  else
    let filtered = filter(s:actions, {i,v -> get(v, 'Name') ==# a:str})
    if len(filtered) == 0
      echomsg 'No action taken: ' . a:str
      return
    endif
    let action = filtered[0]
  endif
  if g:OmniSharp_server_stdio
    call OmniSharp#actions#codeactions#Run(action)
  else
    let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
    let command = printf('runCodeAction(''%s'', ''%s'')', s:mode, command)
    let result = OmniSharp#py#Eval(command)
    if OmniSharp#py#CheckForError() | return | endif
    if !result
      echo 'No action taken'
    endif
  endif
endfunction

function! fzf#OmniSharp#GetCodeActions(mode, actions) abort
  let s:match_on_prefix = 0
  let s:actions = a:actions

  if has('win32')
    " Check whether any actions contain non-ascii characters. These are not
    " reliably passed to FZF and back, so rather than matching on the action
    " name, an index will be prefixed and the selected action will be selected
    " by prefix instead.
    for action in s:actions
      if action.Name =~# '[^\x00-\x7F]'
        let s:match_on_prefix = 1
        break
      endif
    endfor
    if s:match_on_prefix
      call map(s:actions, {i,v -> extend(v, {'Name': i . ': ' . v.Name})})
    endif
  endif

  let s:mode = a:mode
  let actionNames = map(copy(s:actions), 'v:val.Name')

  let fzf_options = copy(get(g:, 'OmniSharp_fzf_options', { 'down': '10%' }))
  call fzf#run(
  \ extend(fzf_options, {
  \ 'source': actionNames,
  \ 'sink': function('s:action_sink')}))
endfunction

function! fzf#OmniSharp#FindUsages(quickfixes, target) abort
  let s:quickfixes = a:quickfixes
  let usages = []
  for quickfix in s:quickfixes
    call add(usages, s:format_line(quickfix))
  endfor
  let fzf_options = copy(get(g:, 'OmniSharp_fzf_options', { 'down': '40%' }))
  call fzf#run(fzf#wrap(
  \ extend(fzf_options, {
  \ 'source': usages,
  \ 'sink': function('s:location_sink')})))
endfunction

" vim:et:sw=2:sts=2
