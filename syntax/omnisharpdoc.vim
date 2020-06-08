if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

syn include @cs syntax/cs.vim
syn region osdcs start="^\%1l" keepend end="\%1l$" contains=@cs

syn match osdSection "^##.\+" contains=osdHash
syn match osdHash contained "#" conceal
syn match osdParam "^`[^`]\+`" contains=osdTick
syn match osdTick contained "`" conceal

hi def link osdSection Statement
hi def link osdParam Comment

hi def OmniSharpActiveParameter cterm=bold,italic,underline gui=bold,italic,underline

let b:current_syntax = 'omnisharpdoc'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
