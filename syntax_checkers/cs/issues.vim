if !has('python')
  finish
endif

if exists('g:loaded_syntastic_cs_issues_checker')
    finish
endif
let g:loaded_syntastic_cs_issues_checker = 1

let s:save_cpo = &cpo
set cpo&vim

function! SyntaxCheckers_cs_issues_IsAvailable() dict abort
    return 1
endfunction

function! SyntaxCheckers_cs_issues_GetLocList() dict abort
    let loc_list = OmniSharp#GetIssues()
    for loc in loc_list
        let loc.valid = 1
        let loc.bufnr = bufnr('%')
        let loc.type = 'W'
    endfor
    return loc_list
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
    \ 'filetype': 'cs',
    \ 'name': 'issues'})

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: set et sts=4 sw=4:
