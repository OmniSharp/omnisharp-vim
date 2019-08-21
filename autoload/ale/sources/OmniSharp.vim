function! ale#sources#OmniSharp#WantResults(buffer) abort
  let g:OmniSharp_ale_diagnostics_requested = 1
  if OmniSharp#FugitiveCheck() | return | endif
  call ale#other_source#StartChecking(a:buffer, 'OmniSharp')
  let opts = { 'BufNum': a:buffer }
  let Callback = function('ale#sources#OmniSharp#ProcessResults', [opts])
  call OmniSharp#stdio#CodeCheck(opts, Callback)
endfunction

function! ale#sources#OmniSharp#ProcessResults(opts, locations) abort
  let locations = a:locations
  for location in locations
    " Use case-insensitive comparison ==?
    if get(location, 'subtype', '') ==? 'style'
      let location['sub_type'] = 'style'
    endif
  endfor
  call ale#other_source#ShowResults(a:opts.BufNum, 'OmniSharp', locations)
endfunction

" vim:et:sw=2:sts=2
