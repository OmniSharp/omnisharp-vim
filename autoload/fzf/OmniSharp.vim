if !has('python')
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
  call OmniSharp#JumpToLocation(quickfix.filename, quickfix.lnum, quickfix.col)
endfunction

function! fzf#OmniSharp#findtypes() abort
  if !OmniSharp#ServerIsRunning()
    return
  endif
  let s:quickfixes = pyeval('findTypes()')
  let types = []
  for quickfix in s:quickfixes
    call add(types, quickfix.text)
  endfor
  call fzf#run({
  \ 'source': types,
  \ 'down': '40%',
  \ 'sink': function('s:location_sink')})
endfunction

function! fzf#OmniSharp#findsymbols() abort
  if !OmniSharp#ServerIsRunning()
    return
  endif
  let s:quickfixes = pyeval('findSymbols()')
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
  let action = index(s:actions, a:str)
  call pyeval(printf('runCodeAction(%s, %d)', string(s:mode), action))
endfunction

function! fzf#OmniSharp#getcodeactions(mode) abort
  let s:actions = pyeval(printf('getCodeActions(%s)', string(a:mode)))
  let s:mode = a:mode
  if empty(s:actions)
    echo 'No code actions found'
    return
  endif
  call fzf#run({
  \ 'source': s:actions,
  \ 'down': '10%',
  \ 'sink': function('s:action_sink')})
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

"
" vim:nofen:fdl=0:ts=2:sw=2:sts=2
