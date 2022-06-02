let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#preview#Display(content, title) abort
  execute 'silent pedit' a:title
  silent wincmd P
  setlocal modifiable noreadonly
  setlocal nobuflisted buftype=nofile bufhidden=wipe
  0,$delete
  silent put =a:content
  0delete _
  set filetype=omnisharpdoc
  setlocal conceallevel=3
  setlocal nomodifiable readonly
  let winid = winnr()
  silent wincmd p
  return winid
endfunction

function! OmniSharp#preview#File(filename, lnum, col) abort
  let lazyredraw_bak = &lazyredraw
  let &lazyredraw = 1
  " Due to cursor jumping bug, opening preview at current file is not as
  " simple as `pedit %`:
  " http://vim.1045645.n5.nabble.com/BUG-BufReadPre-autocmd-changes-cursor-position-on-pedit-td1206965.html
  let winview = winsaveview()
  let l:winnr = winnr()
  execute 'silent pedit' a:filename
  wincmd P
  call cursor(a:lnum, a:col)
  normal! zt
  if winnr() != l:winnr
    wincmd p
    " Jump cursor back to symbol.
    call winrestview(winview)
  endif
  let &lazyredraw = lazyredraw_bak
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
