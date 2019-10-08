let s:save_cpo = &cpoptions
set cpoptions&vim

" TODO: Rename to s:opts
let g:OmniSharp_popup_opts = get(g:, 'OmniSharp_popup_opts', {
\ 'padding': [0,1,1,1],
\ 'border': [1,0,0,0],
\ 'borderchars': [' ']
\})

function! OmniSharp#popup#Buffer(bufnr, lnum) abort
  let s:lastwinid = popup_atcursor(a:bufnr, {
  \ 'firstline': a:lnum,
  \})
  return s:lastwinid
endfunction

function! OmniSharp#popup#Display(content) abort
  let content = map(split(a:content, "\n", 1),
  \ {i,v -> substitute(v, '\r', '', 'g')})
  let s:lastwinid = popup_atcursor(content, g:OmniSharp_popup_opts)
  return s:lastwinid
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
