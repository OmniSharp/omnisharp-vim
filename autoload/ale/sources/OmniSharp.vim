function! ale#sources#OmniSharp#WantResults(buffer) abort
  let g:OmniSharp_diagnostics_requested = 1
  if OmniSharp#FugitiveCheck() | return | endif
  call ale#other_source#StartChecking(a:buffer, 'OmniSharp')
  let opts = { 'BufNum': a:buffer }
  let Callback = function('ale#sources#OmniSharp#ProcessResults', [opts])
  call OmniSharp#actions#diagnostics#StdioCheck(a:buffer, Callback)
endfunction

function! ale#sources#OmniSharp#ProcessResults(opts, locations) abort
  if getbufvar(a:opts.BufNum, 'OmniSharp_debounce_diagnostics', 0)
    call timer_stop(getbufvar(a:opts.BufNum, 'OmniSharp_debounce_diagnostics'))
  endif
  call setbufvar(a:opts.BufNum, 'OmniSharp_debounce_diagnostics',
  \ timer_start(200, function('s:ProcessResults', [a:opts, a:locations])))
endfunction

function! s:ProcessResults(opts, locations, timer) abort
  for location in a:locations
    " Use case-insensitive comparison ==?
    if get(location, 'subtype', '') ==? 'style'
      let location['sub_type'] = 'style'
    endif
  endfor
  try
    call ale#other_source#ShowResults(a:opts.BufNum, 'OmniSharp', a:locations)
  catch
    " When many diagnostic requests are sent or unsolicited diagnostics received
    " (with EnableAnalyzerSupport) during editing, obsolete diagnostics can be
    " sent to ALE, which will result in errors.
  endtry
endfunction

" vim:et:sw=2:sts=2
