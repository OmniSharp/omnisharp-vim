" Load guard
"if ( exists('g:loaded_ctrlp_findsymbols') && g:loaded_ctrlp_findsymbols )
" \ || v:version < 700 || &cp
" finish
"endif
"let g:loaded_ctrlp_findsymbols = 1
if exists('*py3eval')
  let s:pyeval = function('py3eval')
elseif exists('*pyeval')
  let s:pyeval = function('pyeval')
else
  exec s:pycmd ' import json, vim'
  function! s:pyeval(e)
    exec s:pycmd ' vim.command("return " + json.dumps(eval(vim.eval("a:e"))))'
  endfunction
endif

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


" Add this extension's settings to g:ctrlp_ext_vars
"
" Required:
"
" + init: the name of the input function including the brackets and any
"         arguments
"
" + accept: the name of the action function (only the name)
"
" + lname & sname: the long and short names to use for the statusline
"
" + type: the matching type
"   - line : match full line
"   - path : match full line like a file or a directory path
"   - tabs : match until first tab character
"   - tabe : match until last tab character
"
" Optional:
"
" + enter: the name of the function to be called before starting ctrlp
"
" + exit: the name of the function to be called after closing ctrlp
"
" + opts: the name of the option handling function called when initialize
"
" + sort: disable sorting (enabled by default when omitted)
"
" + specinput: enable special inputs '..' and '@cd' (disabled by default)
"
call add(g:ctrlp_ext_vars, {
\ 'init': 'ctrlp#OmniSharp#findcodeactions#init()',
\ 'accept': 'ctrlp#OmniSharp#findcodeactions#accept',
\ 'lname': 'Find Code Actions',
\ 'sname': 'code actions',
\ 'type': 'line',
\ 'sort': 1,
\ 'nolim': 1,
\ })


function! ctrlp#OmniSharp#findcodeactions#setactions(mode, actions) abort
  let s:actions = a:actions
  let s:mode = a:mode
endfunction

" Provide a list of strings to search in
"
" Return: a Vim's List
"
"

function! ctrlp#OmniSharp#findcodeactions#init() abort
  return s:actions
endfunction


" The action to perform on the selected string
"
" Arguments:
"  a:mode   the mode that has been chosen by pressing <cr> <c-v> <c-t> or <c-x>
"           the values are 'e', 'v', 't' and 'h', respectively
"  a:str    the selected string
"
function! ctrlp#OmniSharp#findcodeactions#accept(mode, str) abort
  call ctrlp#exit()
  let action = index(s:actions, a:str)
  call s:pyeval(printf('runCodeAction(%s, %d)', string(s:mode), action))
endfunction

" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! ctrlp#OmniSharp#findcodeactions#id() abort
  return s:id
endfunction

" vim:nofen:fdl=0:ts=2:sw=2:sts=2
