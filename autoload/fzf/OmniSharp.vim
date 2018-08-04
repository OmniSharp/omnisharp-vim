if !(has('python') || has('python3'))
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:location_sink(str) abort
  for quickfix in s:quickfixes
    if quickfix.text == a:str
      break
    endif
  endfor
  echo quickfix.filename
  call OmniSharp#JumpToLocation(quickfix.filename, quickfix.lnum, quickfix.col, 0)
endfunction

function! fzf#OmniSharp#findsymbols(quickfixes) abort
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
  let action = filter(copy(s:actions), {i,v -> get(v, 'Name') ==# a:str})[0]
  let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
  let command = printf('runCodeAction(''%s'', ''%s'')', s:mode, command)
  let result = OmniSharp#py#eval(command)
  if OmniSharp#CheckPyError() | return | endif
  if !result
    echo 'No action taken'
  endif
endfunction

function! fzf#OmniSharp#getcodeactions(mode, actions) abort
  " When using the roslyn server, use /v2/codeactions
  let s:actions = a:actions
  let s:mode = a:mode
  let acts = map(copy(s:actions), {i,v -> get(v, 'Name')})

  call fzf#run({
  \ 'source': acts,
  \ 'down': '10%',
  \ 'sink': function('s:action_sink')})
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
