" Load guard
if ( exists('g:loaded_ctrlp_OmniSharp_findtype') && g:loaded_ctrlp_OmniSharp_findtype )
	\ || v:version < 700 || &cp
	finish
endif
let g:loaded_ctrlp_OmniSharp_findtype = 1


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
	\ 'init': 'ctrlp#OmniSharp#findtype#init()',
	\ 'accept': 'ctrlp#OmniSharp#findtype#accept',
	\ 'lname': 'Find Types',
	\ 'sname': 'types',
	\ 'type': 'tabs',
	\ 'sort': 1,
	\ })


" Provide a list of strings to search in
"
" Return: a Vim's List
"
function! ctrlp#OmniSharp#findtype#init()
	if !OmniSharp#ServerIsRunning()
		return
	endif

  if !OmniSharp#IsSupported()
    finish
  endif

	let s:quickfixes = pyeval("findTypes()")
	let types = []
	for quickfix in s:quickfixes
		call add(types, quickfix.text)
	endfor
	return types
endfunction


" The action to perform on the selected string
"
" Arguments:
"  a:mode   the mode that has been chosen by pressing <cr> <c-v> <c-t> or <c-x>
"           the values are 'e', 'v', 't' and 'h', respectively
"  a:str    the selected string
"
function! ctrlp#OmniSharp#findtype#accept(mode, str)
	call ctrlp#OmniSharp#findtype#exit()
	for quickfix in s:quickfixes
		if quickfix.text == a:str
			break
		endif
	endfor
  call  OmniSharp#JumpToLocation(quickfix.filename, quickfix.lnum, quickfix.col)
endfunction


" (optional) Do something before enterting ctrlp
function! ctrlp#OmniSharp#findtype#enter()
endfunction


" (optional) Do something after exiting ctrlp
function! ctrlp#OmniSharp#findtype#exit()
endfunction


" (optional) Set or check for user options specific to this extension
function! ctrlp#OmniSharp#findtype#opts()
endfunction


" Give the extension an ID
let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)

" Allow it to be called later
function! ctrlp#OmniSharp#findtype#id()
	return s:id
endfunction

" vim:nofen:fdl=0:et:ts=2:sw=2:sts=2
