function! coc#source#OmniSharp#init() abort
  return {
  \ 'shortcut': 'OS',
  \ 'filetypes': ['cs'],
  \ 'triggerCharacters': ['.']
  \ }
endfunction

function! coc#source#OmniSharp#complete(options, callback) abort
  call OmniSharp#actions#complete#Get(a:options.input, a:callback)
endfunction

" vim:et:sw=2:sts=2
