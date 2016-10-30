if !(has('python') || has('python3'))
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:pycmd = has('python3') ? 'python3' : 'python'
let s:pyfile = has('python3') ? 'py3file' : 'pyfile'
if exists('*py3eval')
  let s:pyeval = function('py3eval')
elseif exists('*pyeval')
  let s:pyeval = function('pyeval')
else
  exec s:pycmd 'import json, vim'
  function! s:pyeval(e)
    exec s:pycmd 'vim.command("return " + json.dumps(eval(vim.eval("a:e"))))'
  endfunction
endif

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
  let s:quickfixes = s:pyeval('omnisharp.findTypes()')
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
    echom "DEBUG: server is not running"
    return
  endif
  echom "DEBUG: finding symbols"
  let s:quickfixes = s:pyeval('omnisharp.findSymbols()')
  let symbols = []
  for quickfix in s:quickfixes
    call add(symbols, quickfix.text)
  endfor
  echom "DEBUG: running fzf"
  call fzf#run({
  \ 'source': symbols,
  \ 'down': '40%',
  \ 'sink': function('s:location_sink')})
endfunction

function! s:action_sink(str) abort
  let action = index(s:actions, a:str)
  call s:pyeval(printf('omnisharp.runCodeAction(%s, %d)', string(s:mode), action))
endfunction

function! fzf#OmniSharp#getcodeactions(mode) abort
  let s:actions = s:pyeval(printf('omnisharp.getCodeActions(%s)', string(a:mode)))
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
