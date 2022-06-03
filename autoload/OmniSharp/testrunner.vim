let s:save_cpo = &cpoptions
set cpoptions&vim

let s:state2char = {
\ 'Not run': '|',
\ 'Running': '-',
\ 'Passed': '*',
\ 'Failed': '!'
\}

function! OmniSharp#testrunner#Open() abort
  if !OmniSharp#actions#test#Validate() | return | endif
  call s:Open()
endfunction

function s:Open() abort
  let ft = 'omnisharptest'
  let title = 'OmniSharp Test Runner'
  " If the buffer is listed in a window in the current tab, then focus it
  for winnr in range(1, winnr('$'))
    if getbufvar(winbufnr(winnr), '&filetype') ==# ft
      call win_gotoid(win_getid(winnr))
      break
    endif
  endfor
  if &filetype !=# ft
    " If a buffer with filetype omnisharptest exists, open it in a new split
    for buffer in getbufinfo()
      if getbufvar(buffer.bufnr, '&filetype') ==# ft
        botright split
        execute 'buffer' buffer.bufnr
        break
      endif
    endfor
  endif
  if &filetype !=# ft
    botright new
  endif
  let s:testrunner_bufnr = bufnr()
  silent setlocal noswapfile signcolumn=no conceallevel=3 concealcursor=nv
  setlocal comments=:# commentstring=#\ %s
  set bufhidden=hide
  let &filetype = ft
  execute 'file' title
  call s:Paint()
endfunction

function! OmniSharp#testrunner#Repaint() abort
  " Check that the test runner has been initialised and is still a loaded buffer
  if !exists('s:testrunner_bufnr') | return | endif
  if getbufvar(s:testrunner_bufnr, '&ft') !=# 'omnisharptest' | return | endif
  " If the buffer is listed in a window in the current tab, then focus it
  for winnr in range(1, winnr('$'))
    if winbufnr(winnr) == s:testrunner_bufnr
      let l:winid = win_getid()
      call win_gotoid(win_getid(winnr))
      break
    endif
  endfor
  call s:Paint()
  if exists('l:winid')
    call win_gotoid(l:winid)
  endif
endfunction

function! s:Paint() abort
  let lines = []
  call add(lines, repeat('=', 80))
  call add(lines, '   OmniSharp Test Runner')
  call add(lines, repeat('=', 80))
  call add(lines, '')

  for sln_or_dir in OmniSharp#proc#ListRunningJobs()
    call add(lines, fnamemodify(sln_or_dir, ':t'))
    let job = OmniSharp#proc#GetJob(sln_or_dir)
    if !has_key(job, 'tests') | continue | endif
    for testfile in keys(job.tests)
      call add(lines, '  ' . fnamemodify(testfile, ':.'))
      for name in keys(job.tests[testfile])
        let test = job.tests[testfile][name]
        call add(lines, printf('%s    %s', s:state2char[test.state], name))
      endfor
    endfor
    call add(lines, '')
  endfor

  if bufnr() == s:testrunner_bufnr | let winview = winsaveview() | endif
  call setbufvar(s:testrunner_bufnr, '&modifiable', 1)
  call deletebufline(s:testrunner_bufnr, 1, '$')
  call setbufline(s:testrunner_bufnr, 1, lines)
  call setbufvar(s:testrunner_bufnr, '&modifiable', 0)
  call setbufvar(s:testrunner_bufnr, '&modified', 0)
  if bufnr() == s:testrunner_bufnr |call winrestview(winview) | endif
endfunction

function! OmniSharp#testrunner#SetTests(bufferTests) abort
  let winid = win_getid()
  for buffer in a:bufferTests
    let job = OmniSharp#GetHost(buffer.bufnr).job
    let job.tests = get(job, 'tests', {})
    let filename = fnamemodify(bufname(buffer.bufnr), ':p')
    let existing = get(job.tests, filename, {})
    let job.tests[filename] = existing
    for test in buffer.tests
      let extest = get(existing, test.name, { 'state': 'Not run' })
      let existing[test.name] = extest
      let extest.framework = test.framework
      let extest.lnum = test.nameRange.Start.Line
    endfor
  endfor
  call s:Open()
  call win_gotoid(winid)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
