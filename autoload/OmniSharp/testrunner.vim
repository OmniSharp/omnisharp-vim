scriptencoding utf-8
let s:save_cpo = &cpoptions
set cpoptions&vim

let s:current = get(s:, 'current', {})
let s:runner = get(s:, 'runner', {})


function! OmniSharp#testrunner#Debug() abort
endfunction


function! OmniSharp#testrunner#Init(buffers) abort
  let s:current.log = []
  let s:current.singlebuffer = len(a:buffers) == 1 ? a:buffers[0] : -1
  let s:current.testnames = {}
endfunction


function! OmniSharp#testrunner#Log(message) abort
  call extend(s:current.log, a:message)
endfunction


function! OmniSharp#testrunner#Run() abort
endfunction


function! OmniSharp#testrunner#Navigate() abort
  if &filetype !=# 'omnisharptest' | return | endif
  let bufnr = -1
  let filename = ''
  let lnum = -1
  let col = -1
  let line = getline('.')
  if line =~# '^\a'
    " Project selected - do nothing
  elseif line =~# '^    \f'
    " File selected
    let filename = trim(line)
    let bufnr = bufnr(filename)
  else
    " Stack trace with valid location (filename and possible line number)
    let parsed = matchlist(line, '^> \+__ .* ___ \(.*\) __ \%(line \(\d\+\)\)\?$')
    if len(parsed)
      let filename = parsed[1]
      if parsed[2] !=# ''
        let lnum = str2nr(parsed[2])
      endif
    endif
    if filename ==# ''
      " Search for test
      let testpattern = '[-|*!]        \S'
      if line =~# testpattern
        let testline = line('.')
      else
        let testline = search(testpattern, 'bcnWz')
      endif
      if testline > 0
        let testname = matchlist(getline(testline), '[-|*!]        \zs.*$')[0]
        let projectline = search('^\a', 'bcnWz')
        let projectname = matchlist(getline(projectline), '^\S\+')[0]
        let fileline = search('^    \f', 'bcnWz')
        let filename = matchlist(getline(fileline), '^    \zs.*$')[0]
        let filename = fnamemodify(filename, ':p')
        for sln_or_dir in OmniSharp#proc#ListRunningJobs()
          let job = OmniSharp#proc#GetJob(sln_or_dir)
          if has_key(job, 'tests') && has_key(job.tests, projectname)
            let lnum = job.tests[projectname][filename][testname].lnum
            break
          endif
        endfor
      endif
    endif
  endif
  if bufnr == -1
    if filename !=# ''
      let bufnr = bufnr(filename)
      if bufnr == -1
        let bufnr = bufadd(filename)
        call bufload(bufnr)
      endif
    endif
    if bufnr == -1 | return | endif
  endif
  for winnr in range(1, winnr('$'))
    if winbufnr(winnr) == bufnr
      call win_gotoid(win_getid(winnr))
      break
    endif
  endfor
  if bufnr() != bufnr
    execute 'aboveleft split' filename
  endif
  if lnum != -1
    call cursor(lnum, max([col, 0]))
    if col == -1
      normal! ^
    endif
  endif
endfunction


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
  let s:runner.bufnr = bufnr()
  let &filetype = ft
  execute 'file' title
  call s:Paint()
endfunction

function! s:Repaint() abort
  if !has_key(s:runner, 'bufnr') | return | endif
  if getbufvar(s:runner.bufnr, '&ft') !=# 'omnisharptest' | return | endif
  " If the buffer is listed in a window in the current tab, then focus it
  for winnr in range(1, winnr('$'))
    if winbufnr(winnr) == s:runner.bufnr
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
  let delimiter = get(g:, 'OmniSharp_testrunner_banner_delimeter', '─')
  if get(g:, 'OmniSharp_testrunner_banner', 1)
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
      let errors = get(get(job, 'testerrors', {}), testproject, [])
      call add(lines, testproject . (len(errors) ? ' - ERROR' : ''))
      for errorline in errors
        call add(lines, '<  ' . trim(errorline, ' ', 2))
      endfor
      let loglevel = get(g:, 'OmniSharp_testrunner_loglevel', 'error')
      if loglevel ==? 'all' || (loglevel ==? 'error' && len(errors))
        " The diagnostic logs (build output) are only displayed when a single file
        " is tested, otherwise multiple build outputs are intermingled
        if OmniSharp#GetHost(s:current.singlebuffer).sln_or_dir ==# sln_or_dir
          if len(errors) > 0 && len(s:current.log) > 1
            call add(lines, '<  ' . repeat(delimiter, 10))
          endif
          for log in s:current.log
            call add(lines, '<  ' . trim(log, ' ', 2))
          endfor
        endif
      endif
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
          for messageline in get(test, 'message', [])
            call add(lines, '>            ' . trim(messageline, ' ', 2))
          endfor
          for stacktraceline in get(test, 'stacktrace', [])
            let line = trim(stacktraceline.text)
            if has_key(stacktraceline, 'filename')
              let line = '__ ' . line . ' ___ ' . stacktraceline.filename . ' __ '
            else
              let line = '_._ ' . line . ' _._ '
            endif
            if has_key(stacktraceline, 'lnum')
              let line .= 'line ' . stacktraceline.lnum
            endif
            call add(lines, '>              ' . line)
          endfor
          for outputline in get(test, 'output', [])
            call add(lines, '//          ' . trim(outputline, ' ', 2))
          endfor
        endfor
        call add(lines, '__')
      endfor
      call add(lines, '')
    endfor
  endfor

  if bufnr() == s:runner.bufnr | let winview = winsaveview() | endif
  call setbufvar(s:runner.bufnr, '&modifiable', 1)
  call deletebufline(s:runner.bufnr, 1, '$')
  call setbufline(s:runner.bufnr, 1, lines)
  call setbufvar(s:runner.bufnr, '&modifiable', 0)
  call setbufvar(s:runner.bufnr, '&modified', 0)
  if bufnr() == s:runner.bufnr
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


function! s:UpdateState(bufnr, state, ...) abort
  let opts = a:0 ? a:1 : {}
  let job = OmniSharp#GetHost(a:bufnr).job
  let projectname = s:utils.getProjectName(a:bufnr)
  let job.testerrors = get(job, 'testerrors', {})
  let job.testerrors[projectname] = get(opts, 'errors', [])
  let filename = fnamemodify(bufname(a:bufnr), ':p')
  let tests = job.tests[projectname][filename]
  for testname in get(opts, 'testnames', s:current.testnames[a:bufnr])
    if has_key(tests, testname)
      let stacktrace = []
      for st in get(opts, 'stacktrace', [])
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
      let tests[testname].message = get(opts, 'message', [])
      let tests[testname].stacktrace = stacktrace
      let tests[testname].output = get(opts, 'output', [])
    endif
  endfor
  call s:Repaint()
endfunction

function! OmniSharp#testrunner#StateComplete(location) abort
  if get(a:location, 'type', '') ==# 'E'
    let state = 'Failed'
  elseif get(a:location, 'type', '') ==# 'W'
    let state = 'Not run'
  else
    let state = 'Passed'
  endif
  call s:UpdateState(a:.location.bufnr, state, {
  \ 'testnames': [a:location.fullname],
  \ 'message': get(a:location, 'message', []),
  \ 'stacktrace': get(a:location, 'stacktrace', []),
  \ 'output': get(a:location, 'output', [])
  \})
endfunction

function! OmniSharp#testrunner#StateError(bufnr, messages) abort
  call s:UpdateState(a:bufnr, 'Not run', {'errors': a:messages})
endfunction

function! OmniSharp#testrunner#StateRunning(bufnr, testnames) abort
  let testnames = type(a:testnames) == type([]) ? a:testnames : [a:testnames]
  let s:current.testnames[a:bufnr] = testnames
  call s:UpdateState(a:bufnr, 'Running', {'testnames': testnames})
endfunction

function! OmniSharp#testrunner#StateSkipped(bufnr) abort
  call s:UpdateState(a:bufnr, 'Not run')
endfunction


function! OmniSharp#testrunner#ToggleBanner() abort
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
  let lines = getbufline(s:runner.bufnr, lnum)
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
  call setbufvar(s:runner.bufnr, '&modifiable', 1)
  call setbufline(s:runner.bufnr, lnum, line)
  call setbufvar(s:runner.bufnr, '&modifiable', 0)
  call setbufvar(s:runner.bufnr, '&modified', 0)
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
