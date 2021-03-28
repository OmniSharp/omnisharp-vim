let s:save_cpo = &cpoptions
set cpoptions&vim

" Find all project symbols, or all symbols including a search substring. Symbol
" locations are loaded in the configured selector, :help g:OmniSharp_selector_ui
" Optional arguments:
" symbolName: Partial name of the symbol to search for.
" Callback: When a callback is passed in, it is called after the response is
"           returned (synchronously or asynchronously) with the found symbol
"           locations.
function! OmniSharp#actions#symbols#Find(...) abort
  if a:0 && type(a:1) == type('')
    let filter = a:1
  elseif a:0 > 1 && type(a:2) == type('')
    let filter = a:2
  else
    let filter = ''
  endif
  if a:0 && type(a:1) == type(function('tr'))
    let Callback = a:1
  elseif a:0 > 1 && type(a:2) == type(function('tr'))
    let Callback = a:2
  else
    let Callback = function('s:CBFindSymbol', [filter])
  endif
  call s:Find(filter, 'TypeAndMember', Callback)
endfunction

" Find all project types. This function is similar to
" OmniSharp#actions#symbols#Find() but returns fewer results, and can be
" significanltly faster in a large codebase.
function! OmniSharp#actions#symbols#FindType(...) abort
  if a:0 && type(a:1) == type('')
    let filter = a:1
  elseif a:0 > 1 && type(a:2) == type('')
    let filter = a:2
  else
    let filter = ''
  endif
  if a:0 && type(a:1) == type(function('tr'))
    let Callback = a:1
  elseif a:0 > 1 && type(a:2) == type(function('tr'))
    let Callback = a:2
  else
    let Callback = function('s:CBFindSymbol', [filter])
  endif
  call s:Find(filter, 'Type', Callback)
endfunction

function! s:Find(filter, symbolfilter, Callback) abort
  if !OmniSharp#IsServerRunning() | return | endif
  if g:OmniSharp_server_stdio
    call s:StdioFind(a:filter, a:symbolfilter, a:Callback)
  else
    let locs = OmniSharp#py#Eval(printf('findSymbols(%s, %s)', string(a:filter), string(a:symbolfilter)))
    if OmniSharp#py#CheckForError() | return | endif
    return a:Callback(locs)
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
