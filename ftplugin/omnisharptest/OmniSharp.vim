set bufhidden=hide
set noswapfile
set conceallevel=3
set concealcursor=nv
set foldlevel=2
set foldmethod=syntax
set signcolumn=no
set synmaxcol=3000

nnoremap <buffer> <Plug>(omnisharp_testrunner_togglebanner) :call OmniSharp#testrunner#ToggleBanner()<CR>
nnoremap <buffer> <Plug>(omnisharp_testrunner_run) :call OmniSharp#testrunner#Run()<CR>
nnoremap <buffer> <Plug>(omnisharp_testrunner_debug) :call OmniSharp#testrunner#Debug()<CR>
nnoremap <buffer> <Plug>(omnisharp_testrunner_set_breakpoints) :call OmniSharp#testrunner#SetBreakpoints()<CR>
nnoremap <buffer> <Plug>(omnisharp_testrunner_navigate) :call OmniSharp#testrunner#Navigate()<CR>
nnoremap <buffer> <Plug>(omnisharp_testrunner_remove) :call OmniSharp#testrunner#Remove()<CR>

function! s:map(mode, lhs, plug) abort
  let l:rhs = '<Plug>(' . a:plug . ')'
  if !hasmapto(l:rhs, substitute(a:mode, 'x', 'v', ''))
    execute a:mode . 'map <silent> <buffer>' a:lhs l:rhs
  endif
endfunction

call s:map('n', '<F1>', 'omnisharp_testrunner_togglebanner')
call s:map('n', '<F5>', 'omnisharp_testrunner_run')
call s:map('n', '<F6>', 'omnisharp_testrunner_debug')
call s:map('n', '<F9>', 'omnisharp_testrunner_set_breakpoints')
call s:map('n', '<CR>', 'omnisharp_testrunner_navigate')
call s:map('n', 'dd', 'omnisharp_testrunner_remove')

set foldtext=OmniSharp#testrunner#FoldText()
