if exists("g:loaded_syntastic_cs_syntax_checker")
    finish
endif
let g:loaded_syntastic_cs_syntax_checker = 1

let s:save_cpo = &cpo
set cpo&vim

function! SyntaxCheckers_cs_syntax_IsAvailable() dict
    return 1
endfunction

function! SyntaxCheckers_cs_syntax_GetLocList() dict
    let loc_list = OmniSharp#FindSyntaxErrors()
    for loc in loc_list
        let loc.valid = 1
        let loc.bufnr = bufnr('%')
    endfor
    return loc_list
endfunction

call g:SyntasticRegistry.CreateAndRegisterChecker({
            \ 'filetype': 'cs',
            \ 'name': 'syntax'})

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:nofen:fdl=0:et:ts=2:sw=2:sts=2
