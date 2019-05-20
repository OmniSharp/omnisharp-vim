function! ale#sources#OmniSharp#WantResults(buffer) abort
  if OmniSharp#FugitiveCheck() | return | endif
  if !OmniSharp#IsServerRunning({ 'bufnum': a:buffer }) | return | endif

  call ale#other_source#StartChecking(a:buffer, 'OmniSharp')
  let opts = { 'BufNum': a:buffer }
  call OmniSharp#stdio#CodeCheck(opts, function('s:CBWantResults', [opts]))
endfunction

function! s:CBWantResults(opts, locations) abort
  let locations = a:locations
  for location in locations
    if get(location, 'subtype', '') ==# 'style'
      let location['sub_type'] = 'style'
    endif
  endfor
  call ale#other_source#ShowResults(a:opts.BufNum, 'OmniSharp', locations)
endfunction

" vim:et:sw=2:sts=2
