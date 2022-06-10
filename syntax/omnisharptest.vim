if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

syn region ostIntro start="\%1l" end="^$" contains=ostIntroDelim transparent
syn match ostIntroDelim "^=\+$" contained

syn region ostProject matchgroup=ostProjectName start="^\a.*" end="^$"me=s-1 contains=TOP transparent fold
syn region ostFile matchgroup=ostFileName start="^  \S.*" end="^__$"me=s-1 contains=TOP transparent fold
syn match ostFileDivider "^__$" conceal

syn match ostStateNotRun "^|.*" contains=ostStatePrefix
syn match ostStateRunning "^-.*" contains=ostStatePrefix,ostRunningSuffix
syn match ostStatePassed "^\*.*" contains=ostStatePrefix
syn match ostStateFailed "^!.*" contains=ostStatePrefix
syn match ostStatePrefix "^[|\*!-]" conceal contained

syn match ostRunningSuffix "  -- .*" contained contains=ostRunningSpinner,ostRunningSuffixDivider
syn match ostRunningSuffixDivider "  \zs--" conceal contained
syn match ostRunningSpinner "  -- \zs.*" contained

syn region ostOutput start="^//" end="^[^/]"me=s-1 contains=ostOutputPrefix fold
syn match ostOutputPrefix "^//" conceal contained

hi def link ostIntroDelim PreProc
hi def link ostProjectName Identifier
hi def link ostFileName TypeDef
hi def link ostStateNotRun Comment
hi def link ostStateRunning Identifier
hi def link ostRunningSpinner Normal
hi def link ostStatePassed Title
hi def link ostStateFailed WarningMsg
hi def link ostOutput Comment

let b:current_syntax = 'omnisharptest'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
