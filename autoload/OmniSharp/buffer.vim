let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#buffer#Initialize(job, bufnr, command, opts) abort
  let a:job.pending_requests = get(a:job, 'pending_requests', {})
  let host = getbufvar(a:bufnr, 'OmniSharp_host')
  if get(host, 'initialized') | return | endif
  let a:job.pending_requests[a:bufnr] = get(a:job.pending_requests, a:bufnr, {})
  " More recent requests to the same command replace older pending requests
  let a:job.pending_requests[a:bufnr][a:command] = a:opts
  if has_key(OmniSharp#GetHost(a:bufnr), 'initializing') | return | endif
  let host.initializing = 1
  let Callback = function('s:CBInitialize', [a:job, a:bufnr, host])
  call OmniSharp#actions#buffer#Update(Callback, 1)
endfunction

function! s:CBInitialize(job, bufnr, host) abort
  let a:host.initialized = 1
  unlet a:host.initializing
  call OmniSharp#log#Log(a:job, 'Replaying requests for buffer ' . a:bufnr)
  for key in keys(a:job.pending_requests[a:bufnr])
    call OmniSharp#stdio#Request(key, a:job.pending_requests[a:bufnr][key])
    unlet a:job.pending_requests[a:bufnr][key]
    if empty(a:job.pending_requests[a:bufnr])
      unlet a:job.pending_requests[a:bufnr]
    endif
  endfor
endfunction

function! OmniSharp#buffer#PerformChanges(opts, response) abort
  if !a:response.Success | return | endif
  let changes = get(a:response.Body, 'Changes', [])
  if type(changes) != type([]) || len(changes) == 0
    echo 'No action taken'
  else
    let winview = winsaveview()
    let bufname = bufname('%')
    let bufnr = bufnr('%')
    let unload_bufnrs = []
    let hidden_bak = &hidden | set hidden
    for change in changes
      let modificationType = get(change, 'ModificationType', 0)
      if modificationType == 0 " Modified
        call OmniSharp#locations#Navigate({
        \ 'filename': OmniSharp#util#TranslatePathForClient(change.FileName),
        \}, 'silent')
        call OmniSharp#buffer#Update(change)
        if bufnr('%') != bufnr
          silent write | silent edit
        endif
      elseif modificationType == 1 " Opened
        " ModificationType 1 is typically done in conjunction with a rename
        " (ModificationType 2)
        let bufname = OmniSharp#util#TranslatePathForClient(change.FileName)
        let bufnr = bufadd(bufname)
        " neovim requires that the buffer be explicitly loaded
        call bufload(bufnr)
      elseif modificationType == 2 " Renamed
        let oldbufname = OmniSharp#util#TranslatePathForClient(change.FileName)
        let oldbufnr = bufadd(oldbufname)
        call add(unload_bufnrs, oldbufnr)
      endif
    endfor
    if bufnr('%') != bufnr
      call OmniSharp#locations#Navigate({
      \ 'filename': bufname
      \}, 'silent')
    endif
    for unload_bufnr in unload_bufnrs
      " Don't worry about unwritten changes when there has been a rename - the
      " buffer contents were sent along with the code-action request, so the
      " modified contents are what has been written.
      execute 'bwipeout!' unload_bufnr
    endfor
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
      if startCol > len(getline('.'))
        " We can't set a mark after the last character of the line, so add an
        " extra charaqcter which will be immediately deleted again
        noautocmd normal! a<
        if start == end
          let endCol += 1
          let end[0] = endCol
        endif
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
