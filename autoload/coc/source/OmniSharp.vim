function! coc#source#OmniSharp#init() abort
  return {
  \ 'shortcut': 'OS',
  \ 'filetypes': ['cs'],
  \ 'triggerCharacters': ['.']
  \ }
endfunction

function! coc#source#OmniSharp#complete(options, callback) abort
  let opts = { 'Callback': a:callback }
  call OmniSharp#actions#complete#Get(a:options.input, opts)
endfunction

" vim:et:sw=2:sts=2
