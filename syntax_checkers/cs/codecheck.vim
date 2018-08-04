if !get(g:, 'OmniSharp_loaded', 0)
  finish
endif

if !(has('python') || has('python3'))
  finish
endif

if exists('g:loaded_syntastic_cs_code_checker')
  finish
endif
let g:loaded_syntastic_cs_code_checker = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

function! SyntaxCheckers_cs_code_checker_IsAvailable() dict abort
  return 1
endfunction

function! SyntaxCheckers_cs_code_checker_GetLocList() dict abort
  let loc_list = OmniSharp#CodeCheck()
  for loc in loc_list
    let loc.valid = 1
    let loc.bufnr = bufnr('%')
  endfor
  return loc_list
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
\ 'filetype': 'cs',
\ 'name': 'code_checker'
\})

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
