set bufhidden=hide
set noswapfile
set conceallevel=3
set concealcursor=nv
set foldlevel=2
set foldmethod=syntax
set signcolumn=no

nnoremap <silent> <buffer> <F1> :call OmniSharp#testrunner#toggleBanner()<CR>
