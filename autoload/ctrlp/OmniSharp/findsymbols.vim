
" Load guard
if ( exists('g:OmniSharp_loaded_ctrlp_findsymbols') && g:OmniSharp_loaded_ctrlp_findsymbols )
\ || v:version < 700 || &cp
  finish
endif
let g:loaded_ctrlp_OmniSharp_findsymbols = 1

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
\ 'init': 'ctrlp#OmniSharp#findsymbols#init()',
\ 'accept': 'ctrlp#OmniSharp#findsymbols#accept',
\ 'lname': 'Find Symbols',
\ 'sname': 'symbols',
\ 'type': 'tabs',
\ 'sort': 1,
\ 'nolim': 1,
\ })


function! ctrlp#OmniSharp#findsymbols#setsymbols(quickfixes) abort
  let s:quickfixes = a:quickfixes
  let s:symbols = []
  for quickfix in s:quickfixes
    call add(s:symbols, quickfix.text)
  endfor
endfunction

" Provide a list of strings to search in
"
" Return: a Vim's List
"
function! ctrlp#OmniSharp#findsymbols#init() abort
  return s:symbols
endfunction


" The action to perform on the selected string
"
" Arguments:
"  a:mode   the mode that has been chosen by pressing <cr> <c-v> <c-t> or <c-x>
"           the values are 'e', 'v', 't' and 'h', respectively
"  a:str    the selected string
"
function! ctrlp#OmniSharp#findsymbols#accept(mode, str) abort
  call ctrlp#exit()
  for quickfix in s:quickfixes
    if quickfix.text == a:str
      break
    endif
  endfor
  echo quickfix.filename
  call  OmniSharp#JumpToLocation(quickfix.filename, quickfix.lnum, quickfix.col, 0)
endfunction

" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! ctrlp#OmniSharp#findsymbols#id() abort
  return s:id
endfunction

" vim:et:sw=2:sts=2
