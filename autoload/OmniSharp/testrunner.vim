scriptencoding utf-8
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
  if get(g:, 'OmniSharp_testrunner_banner', 1)
    let delimiter = get(g:, 'OmniSharp_testrunner_banner_delimeter', '─')
    call add(lines, repeat(delimiter, 80))
    call add(lines, '    OmniSharp Test Runner')
    call add(lines, '  ' . repeat(delimiter, 76))
    call add(lines, '    <F1> Toggle this menu (:help omnisharp-test-runner for more)')
    call add(lines, '    <F5> Run test or tests in file under cursor')
    call add(lines, '    <F6> Debug test under cursor')
    call add(lines, '    <CR> Navigate to test or stack trace')
    call add(lines, repeat(delimiter, 80))
  endif

  for sln_or_dir in OmniSharp#proc#ListRunningJobs()
    let job = OmniSharp#proc#GetJob(sln_or_dir)
    if !has_key(job, 'tests') | continue | endif
    for testproject in sort(keys(job.tests))
      call add(lines, testproject)
      for testfile in sort(keys(job.tests[testproject]))
        call add(lines, '    ' . fnamemodify(testfile, ':.'))
        let tests = job.tests[testproject][testfile]
        for name in sort(keys(tests), {a,b -> tests[a].lnum > tests[b].lnum})
          let test = tests[name]
          let state = s:utils.state2char[test.state]
          call add(lines, printf('%s        %s', state, name))
          if state ==# '-' && !has_key(test, 'spintimer')
            call s:spinner.start(test, len(lines))
          endif
          let message = get(test, 'message', [])
          if len(message)
            for messageline in message
              call add(lines, '>            ' . trim(messageline, ' ', 2))
            endfor
          endif
          let stacktrace = get(test, 'stacktrace', [])
          if len(stacktrace)
            for st in stacktrace
              let line = trim(st.text)
              if has_key(st, 'filename')
                let line = '__ ' . line . ' __'
              else
                let line = '_._ ' . line . ' _._'
              endif
              if has_key(st, 'lnum')
                let line .= ' line ' . st.lnum
              endif
              call add(lines, '>              ' . line)
            endfor
          endif
          let output = get(test, 'output', [])
          if len(output)
            for outputline in output
              call add(lines, '//          ' . trim(outputline, ' ', 2))
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

function! s:UpdateState(bufnr, testnames, state, ...) abort
  let message = a:0 ? a:1 : []
  let stacktraceraw = a:0 > 1 ? a:2 : []
  let output = a:0 > 2 ? a:3 : []
  let projectname = s:utils.getProjectName(a:bufnr)
  let filename = fnamemodify(bufname(a:bufnr), ':p')
  let tests = OmniSharp#GetHost(a:bufnr).job.tests[projectname][filename]
  for testname in a:testnames
    if has_key(tests, testname)
      let stacktrace = []
      for st in stacktraceraw
        let parsed = matchlist(st, 'at \(.\+\) in \([^:]\+\)\(:line \(\d\+\)\)\?')
        if len(parsed)
          call add(stacktrace, {
          \ 'text': parsed[1],
          \ 'filename': parsed[2],
          \ 'lnum': str2nr(parsed[4])
          \})
        else
          let parsed = matchlist(st, 'at \(.\+\)')
          if len(parsed)
            call add(stacktrace, {'text': parsed[1]})
          else
            call add(stacktrace, {'text': st})
          endif
        endif
      endfor

      let tests[testname].state = a:state
      let tests[testname].message = message
      let tests[testname].stacktrace = stacktrace
      let tests[testname].output = output
    endif
  endfor
  call s:Repaint()
endfunction

function! OmniSharp#testrunner#StateRunning(bufnr, testnames) abort
  let testnames = type(a:testnames) == type([]) ? a:testnames : [a:testnames]
  let s:lasttestnames = testnames
  call s:UpdateState(a:bufnr, testnames, 'Running')
endfunction

function! OmniSharp#testrunner#StateComplete(location) abort
  if get(a:location, 'type', '') ==# 'E'
    let state = 'Failed'
  elseif get(a:location, 'type', '') ==# 'W'
    let state = 'Not run'
  else
    let state = 'Passed'
  endif
  call s:UpdateState(a:.location.bufnr, [a:location.fullname], state,
  \ get(a:location, 'message', []),
  \ get(a:location, 'stacktrace', []),
  \ get(a:location, 'output', []))
endfunction

function! OmniSharp#testrunner#StateSkipped(bufnr) abort
  call s:UpdateState(a:bufnr, s:lasttestnames, 'Not run')
endfunction


function! OmniSharp#testrunner#toggleBanner() abort
  let g:OmniSharp_testrunner_banner = 1 - get(g:, 'OmniSharp_testrunner_banner', 1)
  call s:Paint()
endfunction


let s:spinner = {}
let s:spinner.steps_ascii = [
\ '<*---->',
\ '<-*--->',
\ '<--*-->',
\ '<---*->',
\ '<----*>',
\ '<---*->',
\ '<--*-->',
\ '<-*--->'
\]
let s:spinner.steps_utf8 = [
\ '∙∙∙',
\ '●∙∙',
\ '∙●∙',
\ '∙∙●',
\ '∙∙∙'
\]

function! s:spinner.spin(test, lnum, timer) abort
  if s:utils.state2char[a:test.state] !=# '-'
    call timer_stop(a:timer)
    return
  endif
  let lnum = a:lnum + (get(g:, 'OmniSharp_testrunner_banner', 1) ? 8 : 0)
  let lines = getbufline(s:testrunner_bufnr, lnum)
  if len(lines) == 0
    call timer_stop(a:timer)
    return
  endif
  let line = lines[0]
  let steps = get(g:, 'OmniSharp_testrunner_spinnersteps',
  \ get(g:, 'OmniSharp_testrunner_spinner_ascii')
  \   ? self.steps_ascii : self.steps_utf8)
  if !has_key(a:test.spinner, 'index')
    let line .= '  -- ' . steps[0]
    let a:test.spinner.index = 0
  else
    let a:test.spinner.index += 1
    if a:test.spinner.index >= len(steps)
      let a:test.spinner.index = 0
    endif
    let step = steps[a:test.spinner.index]
    let line = substitute(line, '  -- \zs.*$', step, '')
  endif
  call setbufvar(s:testrunner_bufnr, '&modifiable', 1)
  call setbufline(s:testrunner_bufnr, lnum, line)
  call setbufvar(s:testrunner_bufnr, '&modifiable', 0)
  call setbufvar(s:testrunner_bufnr, '&modified', 0)
endfunction

function! s:spinner.start(test, lnum) abort
  if !get(g:, 'OmniSharp_testrunner_spinner', 1) | return | endif
  let lnum = a:lnum - (get(g:, 'OmniSharp_testrunner_banner', 1) ? 8 : 0)
  let a:test.spinner = {}
  let a:test.spinner.timer = timer_start(300,
  \ funcref('s:spinner.spin', [a:test, lnum], self),
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
