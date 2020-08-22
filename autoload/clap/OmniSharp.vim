if !OmniSharp#util#CheckCapabilities() | finish | endif

let s:save_cpo = &cpoptions
set cpoptions&vim

function! s:location_sink(str) abort
  for quickfix in s:quickfixes
    if quickfix.text == a:str
      break
    endif
  endfor
  echo quickfix.filename
  call OmniSharp#locations#Navigate(quickfix, 0)
endfunction

function! clap#OmniSharp#FindSymbols(quickfixes) abort
  let s:quickfixes = a:quickfixes
  let symbols = []
  for quickfix in s:quickfixes
    let line = quickfix.filename . ": " . quickfix.lnum . " col " . quickfix.col . '     ' . quickfix.text 
    call add(symbols, line)
  endfor
  let g:clap_provider_symbols = {
  \ 'source': symbols,
  \ 'sink': function('s:location_sink')
  \ }
  exec ':Clap symbols'
endfunction

function! clap#OmniSharp#FindUsages(quickfixes, target) abort
  let s:quickfixes = a:quickfixes
  let usages = []
  for quickfix in s:quickfixes
    let line = quickfix.filename . ": " . quickfix.lnum . " col " . quickfix.col . '     ' . quickfix.text 
    call add(usages, line)
  endfor
  echom usages
  let g:clap_provider_usages = {
  \ 'source': usages,
  \ 'sink': function('s:location_sink')
  \ }
  exec ':Clap usages'
endfunction

" vim:et:sw=2:sts=2
