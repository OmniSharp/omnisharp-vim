if !OmniSharp#util#CheckCapabilities() | finish | endif

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:location_sink(str) abort
  for quickfix in s:quickfixes
    if quickfix.text == a:str
      break
    endif
  endfor
  echo quickfix.filename
  call OmniSharp#locations#Navigate(quickfix, 0)
endfunction

function! fzf#OmniSharp#FindSymbols(quickfixes) abort
  let s:quickfixes = a:quickfixes
  let symbols = []
  for quickfix in s:quickfixes
    call add(symbols, quickfix.text)
  endfor
  call fzf#run({
  \ 'source': symbols,
  \ 'down': '40%',
  \ 'sink': function('s:location_sink')})
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
    " reliably passed to FZF and back, so rather than matching on the action name,
    " an index will be prefixed and the selected action will be selected by prefix
    " instead.
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

  call fzf#run({
  \ 'source': actionNames,
  \ 'down': '10%',
  \ 'sink': function('s:action_sink')})
endfunction

function! fzf#OmniSharp#FindUsages(quickfixes, target) abort
  let s:quickfixes = a:quickfixes
  let usages = []
  for quickfix in s:quickfixes
    let line = quickfix.lnum . ': ' . quickfix.text 
    call add(usages, line)
  endfor
  echom usages
  call fzf#run(fzf#wrap({
  \ 'source': usages,
  \ 'down': '40%',
  \ 'sink': function('s:location_sink')}))
endfunction

" vim:et:sw=2:sts=2
