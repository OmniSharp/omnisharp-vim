let s:save_cpo = &cpoptions
set cpoptions&vim

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the list of locations of
" ambiguous usings.
" This is done instead of showing a quick-fix.
function! OmniSharp#actions#usings#Fix(...) abort
  if a:0 && a:1 isnot 0
    let Callback = a:1
  else
    let Callback = function('s:CBFixUsings')
  endif

  let bufnr = bufnr('%')
  if g:OmniSharp_server_stdio
    call s:StdioFix(Callback, bufnr)
  else
    let locs = OmniSharp#py#Eval('fixUsings()')
    if OmniSharp#py#CheckForError() | return | endif
    return Callback(locs, bufnr)
  endif
endfunction

function! s:StdioFix(Callback, bufnr) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFixRH', [a:Callback, a:bufnr]),
  \ 'Parameters': {
  \   'WantsTextChanges': 1
  \ }
  \}
  call OmniSharp#stdio#Request('/fixusings', opts)
endfunction

function! s:StdioFixRH(Callback, bufnr, response) abort
  if !a:response.Success | return | endif
  normal! m'
  let winview = winsaveview()
  let frombufname = bufname('%')
  let frombufnr = bufnr('%')
  if a:bufnr != frombufnr
    call OmniSharp#locations#Navigate({
    \ 'filename': bufname(a:bufnr)
    \}, 'silent')
  endif
  call OmniSharp#buffer#Update(a:response.Body)
  if bufnr('%') != frombufnr
    call OmniSharp#locations#Navigate({
    \ 'filename': frombufname
    \}, 'silent')
  endif
  call winrestview(winview)
  silent! normal! ``
  if type(a:response.Body.AmbiguousResults) == type(v:null)
    call a:Callback([])
  else
    call a:Callback(OmniSharp#locations#Parse(a:response.Body.AmbiguousResults))
  endif
endfunction

function! s:CBFixUsings(locations) abort
  let numAmbiguous = len(a:locations)
  if numAmbiguous > 0
    let locations = OmniSharp#locations#Modify(a:locations)
    call OmniSharp#locations#SetQuickfix(locations, 'Ambiguous usings')
  endif
  return numAmbiguous
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
