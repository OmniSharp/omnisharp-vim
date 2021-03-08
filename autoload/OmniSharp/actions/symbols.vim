let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#symbols#Find(...) abort
  let filter = a:0 && a:1 isnot 0 ? a:1 : ''
  let symbolfilter = a:0 == 2 ? a:2 : 'TypeAndMember'
  if !OmniSharp#IsServerRunning() | return | endif
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBFindSymbol', [filter])
    call s:StdioFind(filter, symbolfilter, Callback)
  else
    let locs = OmniSharp#py#Eval(printf('findSymbols(%s, %s)', string(filter), string(symbolfilter)))
    if OmniSharp#py#CheckForError() | return | endif
    return s:CBFindSymbol(filter, locs)
  endif
endfunction

function! s:StdioFind(filter, symbolfilter, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback]),
  \ 'Parameters': { 'Filter': a:filter, 'SymbolFilter': a:symbolfilter }
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
  let locations = OmniSharp#locations#Modify(a:locations)
  if g:OmniSharp_selector_ui ==? 'clap'
    call clap#OmniSharp#FindSymbols(locations)
  elseif g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findsymbols', locations]])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#OmniSharp#findsymbols#setsymbols(locations)
    call ctrlp#init(ctrlp#OmniSharp#findsymbols#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#FindSymbols(locations)
  else
    let title = 'Symbols' . (len(a:filter) ? ': ' . a:filter : '')
    call OmniSharp#locations#SetQuickfix(locations, title)
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
