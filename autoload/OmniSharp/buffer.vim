let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#buffer#PerformChanges(opts, response) abort
  if !a:response.Success | return | endif
  let changes = get(a:response.Body, 'Changes', [])
  if type(changes) != type([]) || len(changes) == 0
    echo 'No action taken'
  else
    let winview = winsaveview()
    let bufname = bufname('%')
    let bufnr = bufnr('%')
    let hidden_bak = &hidden | set hidden
    for change in changes
      call OmniSharp#locations#Navigate({
      \ 'filename': OmniSharp#util#TranslatePathForClient(change.FileName),
      \}, 1)
      call OmniSharp#buffer#Update(change)
      if bufnr('%') != bufnr
        silent write | silent edit
      endif
    endfor
    if bufnr('%') != bufnr
      call OmniSharp#locations#Navigate({
      \ 'filename': bufname
      \}, 1)
    endif
    call winrestview(winview)
    let [line, col] = getpos("'`")[1:2]
    if line > 1 && col > 1
      normal! ``
    endif
    let &hidden = hidden_bak
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction

function! OmniSharp#buffer#Update(responseBody) abort
  let changes = get(a:responseBody, 'Changes', [])
  if type(changes) == type(v:null) | let changes = [] | endif

  if len(changes)
    for change in changes
      let text = join(split(change.NewText, '\r\?\n', 1), "\n")
      let startCol = OmniSharp#util#CharToByteIdx(
      \ bufnr('%'), change.StartLine, change.StartColumn)
      let endCol = OmniSharp#util#CharToByteIdx(
      \ bufnr('%'), change.EndLine, change.EndColumn)
      let start = [change.StartLine, startCol]
      let end = [change.EndLine, endCol]
      call cursor(start)
      if startCol > len(getline('.')) && start != end
        " We can't set a mark after the last character of the line, so add an
        " extra charaqcter which will be immediately deleted again
        noautocmd normal! a<
      endif
      call cursor(change.EndLine, max([1, endCol - 1]))
      let lineLen = len(getline('.'))
      if change.StartLine < change.EndLine && (endCol == 1 || lineLen == 0)
        " We can't delete before the first character of the line, so add an
        " extra charaqcter which will be immediately deleted again
        noautocmd normal! i>
      elseif start == end
        " Start and end are the same so insert a character to be replaced
        if startCol > 1
          normal! l
        endif
        noautocmd normal! i=
      endif
      call setpos("'[", [0, change.StartLine, startCol])
      let paste_bak = &paste | set paste
      try
        silent execute "noautocmd keepjumps normal! v`[c\<C-r>=text\<CR>"
      catch
        " E685: Internal error: no text property below deleted line
      endtry
      let &paste = paste_bak
    endfor
  elseif get(a:responseBody, 'Buffer', v:null) != v:null
    let pos = getpos('.')
    let lines = split(a:responseBody.Buffer, '\r\?\n', 1)
    if len(lines) < line('$')
      if exists('*deletebufline')
        call deletebufline('%', len(lines) + 1, '$')
      else
        %delete
      endif
    endif
    call setline(1, lines)
    let pos[1] = min([pos[1], line('$')])
    call setpos('.', pos)
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
