if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

syn region ostIntro start="\%1l" end="^$" contains=ostIntroDelim transparent
syn match ostIntroDelim "^=\+$" contained

syn region ostProject matchgroup=ostProjectName start="^\a.*" end="^$"me=s-1 contains=TOP transparent fold
syn region ostFile start="^    \S.*" end="^__$"me=s-1 contains=TOP transparent fold
syn match ostFileName "^    \S.*" contains=ostFilePath,ostFileExt
syn match ostFilePath "^    \zs\%(\%(\w\+\.\)*\w\+\/\)*\ze\w\+\." conceal contained
syn match ostFileExt "\%(\.\w\+\)\+" conceal contained
syn match ostFileDivider "^__$" conceal

syn match ostStateNotRun "^|.*" contains=ostStatePrefix,ostTestNamespace
syn match ostStateRunning "^-.*" contains=ostStatePrefix,ostTestNamespace,ostRunningSuffix
syn match ostStatePassed "^\*.*" contains=ostStatePrefix,ostTestNamespace
syn match ostStateFailed "^!.*" contains=ostStatePrefix,ostTestNamespace
syn match ostStatePrefix "^[|\*!-]" conceal contained
syn match ostTestNamespace "\%(\w\+\.\)*\ze\w\+" conceal contained

syn match ostRunningSuffix "  -- .*" contained contains=ostRunningSpinner,ostRunningSuffixDivider
syn match ostRunningSuffixDivider "  \zs--" conceal contained
syn match ostRunningSpinner "  -- \zs.*" contained

syn region ostFailure start="^>" end="^[^>]"me=s-1 contains=ostFailurePrefix,ostStackFile,ostStackFileNoLoc fold
syn match ostFailurePrefix "^>" conceal contained
syn region ostStackFile start=" __ "hs=e+1 end=" __" contains=ostStackFileDelimiter,ostStackFileNamespace contained keepend
syn match ostStackFileDelimiter " __" conceal contained
syn region ostStackFileNoLoc start=" _._ "hs=e+1 end=" _._" contains=ostStackFileNoLocDelimiter,ostStackFileNamespace contained keepend
syn match ostStackFileNoLocDelimiter " _._" conceal contained
syn match ostStackFileNamespace "\%(\w\+\.\)*\ze\w\+\.\w\+(" conceal contained
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
hi def link ostStackFile Underlined
hi def link ostOutput Comment

let b:current_syntax = 'omnisharptest'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
