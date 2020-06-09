let s:save_cpo = &cpoptions
set cpoptions&vim

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the number of members
function! OmniSharp#actions#members#Find(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'CallbackType': a:1 } : {}
  if g:OmniSharp_server_stdio
    call s:StdioFind(function('s:CBFindMembers', [opts]))
  else
    let locs = OmniSharp#py#eval('findMembers()')
    if OmniSharp#CheckPyError() | return | endif
    return s:CBFindMembers(opts, locs)
  endif
endfunction

function! s:StdioFind(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback])
  \}
  call OmniSharp#stdio#Request('/currentfilemembersasflat', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse(a:response.Body))
endfunction

function! s:CBFindMembers(opts, locations) abort
  let numMembers = len(a:locations)
  if numMembers > 0
    call OmniSharp#locations#SetQuickfix(a:locations, 'Members')
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(numMembers)
  endif
  return numMembers
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
