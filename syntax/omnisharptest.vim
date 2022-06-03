if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

syn region ostIntro start="\%1l" end="^$" contains=ostIntroDelim transparent
syn match ostIntroDelim "^=\+$" contained

syn match ostStateNotRun "^|.*" contains=ostStateChar
syn match ostStateRunning "^-.*" contains=ostStateChar
syn match ostStatePassed "^\*.*" contains=ostStateChar
syn match ostStateFailed "^!.*" contains=ostStateChar
syn match ostStateChar "^[|\*!-]" conceal contained

hi def link ostIntroDelim PreProc

hi def link ostStateNotRun Comment
hi def link ostStateRunning Identifier
hi def link ostStatePassed Title
hi def link ostStateFailed WarningMsg

let b:current_syntax = 'omnisharptest'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
