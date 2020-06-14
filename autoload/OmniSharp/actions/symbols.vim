let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#symbols#Find(...) abort
  let filter = a:0 && a:1 isnot 0 ? a:1 : ''
  if !OmniSharp#IsServerRunning() | return | endif
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBFindSymbol', [filter])
    call s:StdioFind(filter, Callback)
  else
    let locs = OmniSharp#py#Eval(printf('findSymbols(%s)', string(filter)))
    if OmniSharp#py#CheckForError() | return | endif
    return s:CBFindSymbol(filter, locs)
  endif
endfunction

function! s:StdioFind(filter, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback]),
  \ 'Parameters': { 'Filter': a:filter }
  \}
  call OmniSharp#stdio#Request('/findsymbols', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse(a:response.Body.QuickFixes))
endfunction

function! s:CBFindSymbol(filter, locations) abort
  if empty(a:locations)
    echo 'No symbols found'
    return
  endif
  if g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findsymbols', a:locations]])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#OmniSharp#findsymbols#setsymbols(a:locations)
    call ctrlp#init(ctrlp#OmniSharp#findsymbols#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#FindSymbols(a:locations)
  else
    let title = 'Symbols' . (len(a:filter) ? ': ' . a:filter : '')
    call OmniSharp#locations#SetQuickfix(a:locations, title)
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
