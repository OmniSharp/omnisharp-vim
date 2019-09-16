if get(s:, 'loaded')
    finish
endif
let s:loaded = 1


function! ncm2#sources#OmniSharp#on_complete(ctx) abort
  let kw = matchstr(a:ctx['typed'], '\(\w*\W\)*\zs\w\+$')
  call OmniSharp#GetCompletions(kw, {
                \ results -> ncm2#complete(a:ctx, a:ctx['startccol'], results)
                \ })
endfunction
