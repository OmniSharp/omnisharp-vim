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

function! s:symbols_source() abort
  return map(copy(s:quickfixes), 's:format_line(v:val)')
endfunction

function! clap#OmniSharp#FindSymbols(quickfixes) abort
  let s:quickfixes = a:quickfixes
  Clap symbols
endfunction

let g:clap_provider_symbols = {
\ 'source': function('s:symbols_source'),
\ 'sink': function('s:location_sink')
\}

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

function! s:actions_source() abort
  let s:match_on_prefix = 0

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

  return map(copy(s:actions), 'v:val.Name')
endfunction

function! clap#OmniSharp#GetCodeActions(mode, actions) abort
  let s:actions = a:actions
  let s:mode = a:mode
  Clap actions
endfunction

let g:clap_provider_actions = {
\ 'source': function('s:actions_source'),
\ 'sink': function('s:action_sink')
\}

function! s:usages_source() abort
  return map(copy(s:quickfixes), 's:format_line(v:val)')
endfunction

function! clap#OmniSharp#FindUsages(quickfixes, target) abort
  let s:quickfixes = a:quickfixes
  Clap usages
endfunction

let g:clap_provider_usages = {
\ 'source': function('s:usages_source'),
\ 'sink': function('s:location_sink')
\}

" vim:et:sw=2:sts=2
