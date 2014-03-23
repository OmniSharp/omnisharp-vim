"============================================================================
"File:        cs.vim
"Description: Syntax checking plugin for syntastic.vim
"Maintainer:  Daniel Walker <dwalker@fifo99.com>
"License:     This program is free software. It comes without any warranty,
"             to the extent permitted by applicable law. You can redistribute
"             it and/or modify it under the terms of the Do What The Fuck You
"             Want To Public License, Version 2, as published by Sam Hocevar.
"             See http://sam.zoy.org/wtfpl/COPYING for more details.
"
"============================================================================

if exists("g:loaded_syntastic_cs_issues_checker")
    finish
endif
let g:loaded_syntastic_cs_issues_checker = 1

let s:save_cpo = &cpo
set cpo&vim

function! SyntaxCheckers_cs_issues_IsAvailable() dict
    return 1
endfunction

function! SyntaxCheckers_cs_issues_GetLocList() dict

    let loc_list = OmniSharp#GetIssues()
    for loc in loc_list
        let loc.valid = 1
        let loc.bufnr = bufnr('%')
    endfor
    return loc_list
    "let makeprg = self.makeprgBuild({ 'args_after': '--parse' })

    "let errorformat = '%f(%l\,%c): %trror %m'

    "return SyntasticMake({
        "\ 'makeprg': makeprg,
        "\ 'errorformat': errorformat,
        "\ 'defaults': {'bufnr': bufnr("")} })
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'cs',
    \ 'name': 'issues'})

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set et sts=4 sw=4:
