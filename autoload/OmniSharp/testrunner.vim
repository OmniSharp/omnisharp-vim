let s:save_cpo = &cpoptions
set cpoptions&vim

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
    let job = OmniSharp#proc#GetJob(sln_or_dir)
    if !has_key(job, 'tests') | continue | endif
    for testproject in sort(keys(job.tests))
      call add(lines, testproject)
      for testfile in sort(keys(job.tests[testproject]))
        call add(lines, '  ' . fnamemodify(testfile, ':.'))
        let tests = job.tests[testproject][testfile]
        for name in sort(keys(tests), {a,b -> tests[a].lnum > tests[b].lnum})
          let test = tests[name]
          let state =  s:utils.state2char[test.state]
          call add(lines, printf('%s       %s', state, name))
          if state ==# '-' && !has_key(test, 'spintimer')
            call s:spinner.start(test, len(lines))
          endif
          let output = get(test, 'output', [])
          if len(output)
            for outputline in output
              call add(lines, '//          ' . outputline)
            endfor
          endif
        endfor
        call add(lines, '__')
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
  if bufnr() == s:testrunner_bufnr
    call winrestview(winview)
    syn sync fromstart
  endif
endfunction


function! OmniSharp#testrunner#SetTests(bufferTests) abort
  let winid = win_getid()
  for buffer in a:bufferTests
    let job = OmniSharp#GetHost(buffer.bufnr).job
    let job.tests = get(job, 'tests', {})
    let projectname = s:utils.getProjectName(buffer.bufnr)
    let testproject = get(job.tests, projectname, {})
    let job.tests[projectname] = testproject
    let filename = fnamemodify(bufname(buffer.bufnr), ':p')
    let existing = get(testproject, filename, {})
    let testproject[filename] = existing
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

function! s:UpdateState(bufnr, testnames, state, output) abort
  let projectname = s:utils.getProjectName(a:bufnr)
  let filename = fnamemodify(bufname(a:bufnr), ':p')
  let tests = OmniSharp#GetHost(a:bufnr).job.tests[projectname][filename]
  for testname in a:testnames
    if has_key(tests, testname)
      let tests[testname].state = a:state
      let tests[testname].output = a:output
    endif
  endfor
  call s:Repaint()
endfunction

function! OmniSharp#testrunner#StateRunning(bufnr, testnames) abort
  let testnames = type(a:testnames) == type([]) ? a:testnames : [a:testnames]
  let s:lasttestnames = testnames
  call s:UpdateState(a:bufnr, testnames, 'Running', [])
endfunction

function! OmniSharp#testrunner#StateComplete(location) abort
  if get(a:location, 'type', '') ==# 'E'
    let state = 'Failed'
  elseif get(a:location, 'type', '') ==# 'W'
    let state = 'Not run'
  else
    let state = 'Passed'
  endif
  let output = get(a:location, 'output', [])
  call s:UpdateState(a:.location.bufnr, [a:location.fullname], state, output)
endfunction

function! OmniSharp#testrunner#StateSkipped(bufnr) abort
  call s:UpdateState(a:bufnr, s:lasttestnames, 'Not run', [])
endfunction


let s:spinner = {}
let s:spinner.steps = get(g:, 'OmniSharp_testrunner_spinnersteps', [
\ '<*---->',
\ '<-*--->',
\ '<--*-->',
\ '<---*->',
\ '<----*>',
\ '<---*->',
\ '<--*-->',
\ '<-*--->'])

function! s:spinner.spin(test, lnum, timer) abort
  if s:utils.state2char[a:test.state] !=# '-'
    call timer_stop(a:timer)
    return
  endif
  let lines = getbufline(s:testrunner_bufnr, a:lnum)
  if len(lines) == 0
    call timer_stop(a:timer)
    return
  endif
  let line = lines[0]
  if !has_key(a:test.spinner, 'index')
    let line .= '  -- ' . s:spinner.steps[0]
    let a:test.spinner.index = 0
  else
    let a:test.spinner.index += 1
    if a:test.spinner.index >= len(s:spinner.steps)
      let a:test.spinner.index = 0
    endif
    let step = s:spinner.steps[a:test.spinner.index]
    let line = substitute(line, '  -- \zs.*$', step, '')
  endif
  call setbufvar(s:testrunner_bufnr, '&modifiable', 1)
  call setbufline(s:testrunner_bufnr, a:lnum, line)
  call setbufvar(s:testrunner_bufnr, '&modifiable', 0)
  call setbufvar(s:testrunner_bufnr, '&modified', 0)
endfunction

function! s:spinner.start(test, lnum) abort
  if !get(g:, 'OmniSharp_testrunner_spinner', 1) | return | endif
  let a:test.spinner = {}
  let a:test.spinner.timer = timer_start(300,
  \ funcref('s:spinner.spin', [a:test, a:lnum], self),
  \ {'repeat': -1})
endfunction


let s:utils = {}

let s:utils.state2char = {
\ 'Not run': '|',
\ 'Running': '-',
\ 'Passed': '*',
\ 'Failed': '!'
\}

function! s:utils.getProjectName(bufnr) abort
  let project = OmniSharp#GetHost(a:bufnr).project
  let msbuildproject = get(project, 'MsBuildProject', {})
  return get(msbuildproject, 'AssemblyName', '_Default')
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
