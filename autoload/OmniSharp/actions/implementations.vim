let s:save_cpo = &cpoptions
set cpoptions&vim

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the number of implementations
function! OmniSharp#actions#implementations#Find(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'CallbackType': a:1 } : {}
  let target = expand('<cword>')
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBFindImplementations', [target, opts])
    call s:StdioFind(Callback)
  else
    let locs = OmniSharp#py#eval('findImplementations()')
    if OmniSharp#CheckPyError() | return | endif
    return s:CBFindImplementations(target, opts, locs)
  endif
endfunction

function! s:StdioFind(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback])
  \}
  call OmniSharp#stdio#Request('/findimplementations', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  let responses = a:response.Body.QuickFixes
  if type(responses) == type([])
    call a:Callback(OmniSharp#locations#Parse(responses))
  else
    call a:Callback([])
  endif
endfunction

function! s:CBFindImplementations(target, opts, locations) abort
  let numImplementations = len(a:locations)
  if numImplementations == 0
    echo 'No implementations found'
  elseif numImplementations == 1
    call OmniSharp#locations#Navigate(a:locations[0], 0)
  else " numImplementations > 1
    call OmniSharp#locations#SetQuickfix(a:locations,
    \ 'Implementations: ' . a:target)
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(numImplementations)
  endif
  return numImplementations
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
