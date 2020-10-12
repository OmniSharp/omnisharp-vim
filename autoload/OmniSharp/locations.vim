let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#locations#Navigate(location, noautocmds) abort
  if a:location.filename !=# ''
    " Update the ' mark, adding this location to the jumplist.
    normal! m'
    if fnamemodify(a:location.filename, ':p') !=# expand('%:p')
      execute
      \ (a:noautocmds ? 'noautocmd' : '')
      \ (&modified && !&hidden ? 'split' : 'edit')
      \ fnameescape(a:location.filename)
    endif
    if get(a:location, 'lnum', 0) > 0
      let col = get(a:location, 'vcol', 0)
      \ ? OmniSharp#util#CharToByteIdx(
      \     a:location.filename, a:location.lnum, a:location.col)
      \ : a:location.col
      call cursor(a:location.lnum, col)
      redraw
    endif
    return 1
  endif
endfunction

function! OmniSharp#locations#Parse(quickfixes) abort
  let locations = []
  for quickfix in a:quickfixes
    let location = {
    \ 'filename': has_key(quickfix, 'FileName')
    \   ? OmniSharp#util#TranslatePathForClient(quickfix.FileName)
    \   : expand('%:p'),
    \ 'text': get(quickfix, 'Text', get(quickfix, 'Message', '')),
    \ 'lnum': quickfix.Line,
    \ 'col': quickfix.Column,
    \ 'vcol': 1
    \}
    if has_key(quickfix, 'EndLine') && has_key(quickfix, 'EndColumn')
      let location.end_lnum = quickfix.EndLine
      let location.end_col = quickfix.EndColumn - 1
    endif
    call add(locations, location)
  endfor
  return locations
endfunction

function! OmniSharp#locations#Preview(location) abort
  if OmniSharp#popup#Enabled()
    let bufnr = bufadd(a:location.filename)
    " neovim requires that the buffer be explicitly loaded
    call bufload(bufnr)
    call OmniSharp#popup#Buffer(bufnr, a:location.lnum, {})
  else
    call OmniSharp#preview#File(a:location.filename, a:location.lnum, a:location.col)
  endif
endfunction

function! OmniSharp#locations#SetQuickfix(list, title) abort
  call s:SetQuickfixFromDict(a:list, {'title': a:title})
endfunction

function! OmniSharp#locations#SetQuickfixWithVerticalAlign(list, title) abort
  call s:SetQuickfixFromDict(a:list, {'title': a:title, 'quickfixtextfunc': 'OmniSharp#locations#_quickfixtextfuncAlign'})
endfunction

function! s:SetQuickfixFromDict(list, dict) abort
  if !has('patch-8.0.0657')
  \ || setqflist([], ' ', extend(a:dict, {'nr': '$', 'items': a:list})) == -1
    call setqflist(a:list)
  endif
  silent doautocmd <nomodeline> QuickFixCmdPost OmniSharp
  if g:OmniSharp_open_quickfix
    botright cwindow
  endif
endfunction

function! OmniSharp#locations#_quickfixtextfuncAlign(info) abort
  if a:info.quickfix
    let qfl = getqflist({'id': a:info.id, 'items': 0}).items
  else
    let qfl = getloclist(a:info.winid, {'id': a:info.id, 'items': 0}).items
  endif
  let l = []
  let efm_type = {'e': 'error', 'w': 'warning', 'i': 'info', 'n': 'note'}
  let lnum_width =   len(max(map(range(a:info.start_idx - 1, a:info.end_idx - 1), { _,v -> qfl[v].lnum })))
  let col_width =    len(max(map(range(a:info.start_idx - 1, a:info.end_idx - 1), {_, v -> qfl[v].col})))
  let fname_width =  max(map(range(a:info.start_idx - 1, a:info.end_idx - 1), {_, v -> strchars(fnamemodify(bufname(qfl[v].bufnr), ':t'), 1)}))
  let type_width =   max(map(range(a:info.start_idx - 1, a:info.end_idx - 1), {_, v -> strlen(get(efm_type, qfl[v].type, ''))}))
  let errnum_width = len(max(map(range(a:info.start_idx - 1, a:info.end_idx - 1),{_, v -> qfl[v].nr})))
  for idx in range(a:info.start_idx - 1, a:info.end_idx - 1)
    let e = qfl[idx]
    if !e.valid
      call add(l, '|| ' . e.text)
    else
      if e.lnum == 0 && e.col == 0
        call add(l, bufname(e.bufnr))
      else
        let fname = fnamemodify(printf('%-*S', fname_width, bufname(e.bufnr)), ':t')
        let lnum = printf('%*d', lnum_width, e.lnum)
        let col = printf('%*d', col_width, e.col)
        let type = printf('%-*S', type_width, get(efm_type, e.type, ''))
        let errnum = ''
        if e.nr
          let errnum = printf('%*d', errnum_width + 1, e.nr)
        endif
        call add(l, printf('%s|%s col %s %s%s| %s', fname, lnum, col, type, errnum, e.text))
      endif
    endif
  endfor
  return l
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
