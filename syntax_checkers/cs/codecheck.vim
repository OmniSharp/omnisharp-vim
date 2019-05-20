if !get(g:, 'OmniSharp_loaded', 0) | finish | endif
if !OmniSharp#util#CheckCapabilities() | finish | endif
if exists('g:loaded_syntastic_cs_code_checker') | finish | endif
let g:loaded_syntastic_cs_code_checker = 1

let s:save_cpo = &cpoptions
set cpoptions&vim

function! SyntaxCheckers_cs_code_checker_IsAvailable() dict abort
  return 1
endfunction

function! SyntaxCheckers_cs_code_checker_GetLocList() dict abort
  if g:OmniSharp_server_stdio
    let s:codecheck_pending = 1
    call OmniSharp#CodeCheck({_ -> execute('let s:codecheck_pending = 0')})
    let starttime = reltime()
    " Syntastic is synchronous so must wait for the callback to be completed.
    while s:codecheck_pending && reltime(starttime)[0] < g:OmniSharp_timeout
      sleep 50m
    endwhile
    if s:codecheck_pending | return [] | endif
    let loc_list = b:codecheck
  else
    let loc_list = OmniSharp#CodeCheck()
  endif
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
