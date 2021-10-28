if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

syn match oslName "^\[\w\{4,5\}\]: .*$"hs=s+7 contains=oslTrace,oslDebug,oslInformation,oslWarning,oslError,oslCritical

syn match oslTrace "^\[trce\]"ms=s+1,me=e-1 contained
syn match oslDebug "^\[dbug\]"ms=s+1,me=e-1 contained
syn match oslInformation "^\[info\]"ms=s+1,me=e-1 contained
syn match oslWarning "^\[warn\]"ms=s+1,me=e-1 contained
syn match oslError "^\[fail\]"ms=s+1,me=e-1 contained
syn match oslError "^\[ERROR\]"ms=s+1,me=e-1 contained
syn match oslCritical "^\[crit\]"ms=s+1,me=e-1 contained

syn match oslEndpoint "^Request: .*$"hs=s+9
syn match oslServerEndpoint "^Server \%(Request\|Response\): .*$"hs=s+16

syn region oslRequestResponse start="\*\{12}\s\+\%(Request\|Response\)\%(\s(.\{-})\)\?\s\+\*\{12}" end="^}" transparent fold

hi def link oslName Comment

hi def link oslTrace Identifier
hi def link oslDebug NonText
hi def link oslInformation Type
hi def link oslWarning WarningMsg
hi def link oslError ErrorMsg
hi def link oslCritical ErrorMsg

hi def link oslEndpoint Identifier
hi def link oslServerEndpoint Constant

let b:current_syntax = 'omnisharplog'

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
