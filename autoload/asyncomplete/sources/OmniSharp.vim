function! asyncomplete#sources#OmniSharp#completor(opt, ctx) abort
  let column = a:ctx['col']
  let typed = a:ctx['typed']

  let kw = matchstr(typed, '\(\w*\W\)*\zs\w\+$')
  let kwlen = len(kw)

  let startcol = column - kwlen

  let opts = {
  \ 'startcol': startcol - 1,
  \ 'Callback': {results->
  \   asyncomplete#complete(a:opt['name'], a:ctx, startcol, results)}
  \}
  call OmniSharp#actions#complete#Get(kw, opts)
endfunction

" vim:et:sw=2:sts=2
