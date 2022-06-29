if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

syn region ostBanner start="\%1l" end="\%8l$" contains=ostBannerDelim,ostBannerTitle,ostBannerHelp transparent keepend
syn match ostBannerHelp "^    .*$" contained contains=ostBannerMap,ostBannerLink
syn match ostBannerMap  "^    \S\+" contained
syn match ostBannerLink ":help [[:alnum:]-]\+" contained
syn match ostBannerTitle "\%2l^.\+$" contained
syn match ostBannerDelim "\%1l^.*$" contained
syn match ostBannerDelim "\%3l^.*$" contained
syn match ostBannerDelim "\%8l^.*$" contained

syn match ostProjectKey ";[^;]*;[^;]*;.*" contains=ostSolution,ostAssembly,ostProjectDelimiter,ostProjectError
syn match ostSolution "\%(^;[^;]\+;\)\@<=[^;]\+" contained conceal
syn match ostAssembly "\%(^;\)\@<=[^;]\+\ze;[^;]\+;" contained
syn match ostProjectDelimiter ";" contained conceal
syn match ostProjectError "ERROR$" contained
syn region ostProject start="^;" end="^$"me=s-1 contains=TOP transparent fold

syn region ostError start="^<" end="^[^<]"me=s-1 contains=ostErrorPrefix,ostStackFile,ostStackFileNoLoc fold
syn match ostErrorPrefix "^<" conceal contained
syn match ostFileName "^    \S.*" contains=ostFilePath,ostFileExt
syn match ostFilePath "\%(^    \)\@<=\f\{-}\ze[^/\\]\+\.csx\?$" conceal contained
syn match ostFileExt "\.csx\?$" conceal contained
syn region ostFile start="^    \S.*" end="^__$"me=s-1 contains=TOP transparent fold
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

syn region ostFailure start="^>" end="^[^>]"me=s-1 contains=ostFailurePrefix,ostStackLoc,ostStackNoLoc fold
syn match ostFailurePrefix "^>" conceal contained
syn region ostStackLoc start=" __ "hs=e+1 end=" __ "he=e-1 contains=ostStackFile,ostStackDelimiter,ostStackNamespace contained keepend
syn region ostStackFile start=" ___ " end=" __ "he=e-1 contains=ostStackFileDelimiter,ostStackDelimiter conceal contained
syn match ostStackDelimiter " __ "he=e-1 conceal contained
syn match ostStackFileDelimiter " ___ " conceal contained
syn region ostStackNoLoc start=" _._ "hs=e+1 end=" _._" contains=ostStackNoLocDelimiter,ostStackNamespace contained keepend
syn match ostStackNoLocDelimiter " _._" conceal contained
syn match ostStackNamespace "\%(\w\+\.\)*\ze\w\+\.\w\+(" conceal contained
syn region ostOutput start="^//" end="^[^/]"me=s-1 contains=ostOutputPrefix fold
syn match ostOutputPrefix "^//" conceal contained

hi def link ostBannerDelim PreProc
hi def link ostBannerTitle Normal
hi def link ostBannerHelp Comment
hi def link ostBannerMap PreProc
hi def link ostBannerLink Identifier
hi def link ostAssembly Identifier
hi def link ostSolution Normal
hi def link ostProjectError WarningMsg
hi def link ostFileName TypeDef
hi def link ostStateNotRun Comment
hi def link ostStateRunning Identifier
hi def link ostRunningSpinner Normal
hi def link ostStatePassed Title
hi def link ostStateFailed WarningMsg
hi def link ostStackLoc Identifier
hi def link ostOutput Comment

" Highlights for normally concealed elements
hi def link ostProjectDelimiter NonText
hi def link ostErrorPrefix NonText
hi def link ostFileDivider NonText
hi def link ostStatePrefix NonText
hi def link ostFailurePrefix NonText
hi def link ostRunningSuffixDivider NonText
hi def link ostStackDelimiter NonText
hi def link ostStackFileDelimiter NonText
hi def link ostStackNoLocDelimiter NonText
hi def link ostOutputPrefix NonText
hi def link ostStackFile WarningMsg

let b:current_syntax = 'omnisharptest'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
