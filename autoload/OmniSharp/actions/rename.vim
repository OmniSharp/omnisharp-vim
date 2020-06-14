let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#rename#Prompt() abort
  let renameto = inputdialog('Rename to: ', expand('<cword>'))
  if renameto !=# ''
    call OmniSharp#actions#rename#To(renameto)
  endif
endfunction

function! OmniSharp#actions#rename#To(renameto, ...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  if g:OmniSharp_server_stdio
    call s:StdioRename(a:renameto, opts)
  else
    let command = printf('renameTo(%s)', string(a:renameto))
    let changes = OmniSharp#py#Eval(command)
    if OmniSharp#py#CheckForError() | return | endif

    let save_lazyredraw = &lazyredraw
    let save_eventignore = &eventignore
    let buf = bufnr('%')
    let curpos = getpos('.')
    let view = winsaveview()
    try
      set lazyredraw eventignore=all
      for change in changes
        execute 'silent hide edit' fnameescape(change.FileName)
        let modified = &modified
        let content = split(change.Buffer, '\r\?\n')
        silent % delete _
        silent 1put =content
        silent 1 delete _
        if !modified
          silent update
        endif
      endfor
    finally
      if bufnr('%') != buf
        exec 'buffer ' . buf
      endif
      call setpos('.', curpos)
      call winrestview(view)
      silent update
      let &eventignore = save_eventignore
      silent edit  " reload to apply syntax
      let &lazyredraw = save_lazyredraw
    endtry
    if has_key(opts, 'Callback')
      call opts.Callback()
    endif
  endif
endfunction

function! s:StdioRename(renameto, opts) abort
  let opts = {
  \ 'ResponseHandler': function('OmniSharp#buffer#PerformChanges', [a:opts]),
  \ 'Parameters': {
  \   'RenameTo': a:renameto,
  \   'WantsTextChanges': 1
  \ }
  \}
  call OmniSharp#stdio#Request('/rename', opts)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
