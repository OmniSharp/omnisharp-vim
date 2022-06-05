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

function! s:Repaint() abort
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
        let state =  s:state2char[test.state]
        call add(lines, printf('%s    %s', state, name))
        if state ==# '-' && !has_key(test, 'spintimer')
          call s:SpinnerStart(test, len(lines))
        endif
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

function! s:SpinnerSpin(test, lnum, timer) abort
  if s:state2char[a:test.state] !=# '-'
    call timer_stop(a:timer)
    return
  endif
  let lines = getbufline(s:testrunner_bufnr, a:lnum)
  if len(lines) == 0
    call timer_stop(a:timer)
    return
  endif
  let line = lines[0]
  let steps = get(g:, 'OmniSharp_testrunner_spinnersteps', [
  \ '<*---->', '<-*--->', '<--*-->', '<---*->',
  \ '<----*>', '<---*->', '<--*-->', '<-*--->'])
  if !has_key(a:test.spinner, 'index')
    let line .= '  -- ' . steps[0]
    let a:test.spinner.index = 0
  else
    let a:test.spinner.index += 1
    if a:test.spinner.index >= len(steps)
      let a:test.spinner.index = 0
    endif
    let line = substitute(line, '  -- \zs.*$', steps[a:test.spinner.index], '')
  endif
  call setbufvar(s:testrunner_bufnr, '&modifiable', 1)
  call setbufline(s:testrunner_bufnr, a:lnum, line)
  call setbufvar(s:testrunner_bufnr, '&modifiable', 0)
  call setbufvar(s:testrunner_bufnr, '&modified', 0)
endfunction

function! s:SpinnerStart(test, lnum) abort
  let a:test.spinner = {}
  let a:test.spinner.timer = timer_start(300,
  \ funcref('s:SpinnerSpin', [a:test, a:lnum]),
  \ {'repeat': -1})
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

function! s:UpdateState(bufnr, testnames, state) abort
  let job = OmniSharp#GetHost(a:bufnr).job
  let filename = fnamemodify(bufname(a:bufnr), ':p')
  let tests = get(job.tests, filename, {})
  for testname in a:testnames
    if has_key(tests, testname)
      let tests[testname].state = a:state
    endif
  endfor
  call s:Repaint()
endfunction

function! OmniSharp#testrunner#StateRunning(bufnr, testnames) abort
  let testnames = type(a:testnames) == type([]) ? a:testnames : [a:testnames]
  let s:lasttestnames = testnames
  call s:UpdateState(a:bufnr, testnames, 'Running')
endfunction

function! OmniSharp#testrunner#StateSkipped(bufnr, ...) abort
  let testnames = a:0 ? (type(a:1) == type([]) ? a:1 : [a:1]) : s:lasttestnames
  call s:UpdateState(a:bufnr, testnames, 'Not run')
endfunction

function! OmniSharp#testrunner#StatePassed(bufnr, ...) abort
  let testnames = a:0 ? (type(a:1) == type([]) ? a:1 : [a:1]) : s:lasttestnames
  call s:UpdateState(a:bufnr, testnames, 'Passed')
endfunction

function! OmniSharp#testrunner#StateFailed(bufnr, ...) abort
  let testnames = a:0 ? (type(a:1) == type([]) ? a:1 : [a:1]) : s:lasttestnames
  call s:UpdateState(a:bufnr, testnames, 'Failed')
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
