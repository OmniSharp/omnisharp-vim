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
  let overrides = get(g:, 'OmniSharp_diagnostic_overrides', {})
  for quickfix in a:quickfixes
    let text = get(quickfix, 'Text', get(quickfix, 'Message', ''))
    if get(g:, 'OmniSharp_diagnostic_showid', 0) && has_key(quickfix, 'Id')
      let text = quickfix.Id . ': ' . text
    endif
    if has_key(quickfix, 'FileName')
      let filename = OmniSharp#util#TranslatePathForClient(quickfix.FileName)
    else
      let filename = expand('%:p')
    endif
    let location = {
    \ 'filename': filename,
    \ 'text': text,
    \ 'lnum': quickfix.Line,
    \ 'col': quickfix.Column,
    \ 'vcol': 1
    \}
    if has_key(quickfix, 'EndLine') && has_key(quickfix, 'EndColumn')
      let location.end_lnum = quickfix.EndLine
      let location.end_col = quickfix.EndColumn - 1
    endif
    let loglevel = get(quickfix, 'LogLevel', '')
    if loglevel !=# ''
      let diag_id = get(quickfix, 'Id', '-')
      if index(keys(overrides), diag_id) >= 0
        if overrides[diag_id].type ==? 'None'
          continue
        endif
        call extend(location, overrides[diag_id])
      else
        if loglevel ==# 'Error'
          let location.type = 'E'
        elseif loglevel ==# 'Info'
          let location.type = 'I'
        else
          let location.type = 'W'
        endif
        if loglevel ==# 'Hidden'
          let location.subtype = 'Style'
        endif
      endif
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

function! OmniSharp#locations#SetQuickfix(list, title)
  if !has('patch-8.0.0657')
  \ || setqflist([], ' ', {'nr': '$', 'items': a:list, 'title': a:title}) == -1
    call setqflist(a:list)
  endif
  silent doautocmd <nomodeline> QuickFixCmdPost OmniSharp
  if g:OmniSharp_open_quickfix
    botright cwindow
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
