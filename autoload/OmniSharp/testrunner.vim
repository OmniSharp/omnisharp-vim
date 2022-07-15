scriptencoding utf-8
let s:save_cpo = &cpoptions
set cpoptions&vim

let s:current = get(s:, 'current', {})
let s:runner = get(s:, 'runner', {})
let s:tests = get(s:, 'tests', {})

" Expose s:tests for custom scripting
function! OmniSharp#testrunner#GetTests() abort
  return s:tests
endfunction


function! OmniSharp#testrunner#Debug() abort
  let filename = ''
  let line = getline('.')
  if line =~# '^;' || line =~# '^    \f'
    return s:utils.log.warn('Select a test to debug')
  else
    let test = s:utils.findTest()
    if has_key(test, 'filename')
      call OmniSharp#actions#test#Debug(0, test.filename, test.name)
    endif
  endif
endfunction


function! OmniSharp#testrunner#Init(buffers) abort
  let s:current.log = []
  let s:current.singlebuffer = len(a:buffers) == 1 ? a:buffers[0] : -1
  let s:current.testnames = {}
endfunction


function! OmniSharp#testrunner#FoldText() abort
  let line = getline(v:foldstart)
  if line =~# '^;'
    " Project
    let projectkey = matchlist(line, '^\S\+')[0]
    let [assembly, _] = split(projectkey, ';')
    let ntests = 0
    for filename in keys(s:tests[projectkey].files)
      let ntests += len(s:tests[projectkey].files[filename].tests)
    endfor
    let err = match(line, '; ERROR$') == -1 ? '' : ' ERROR'
    return printf('%s [%d]%s', assembly, ntests, err)
  elseif line =~# '^    \f'
    " File
    let filename = trim(line)
    let displayname = matchlist(filename, '^\f\{-}\([^/\\]\+\)\.csx\?$')[1]
    " Position the cursor so that search() is relative to the fold, not the
    " actual cursor position
    let winview = winsaveview()
    call cursor(v:foldstart, 0)
    let projectline = search('^;', 'bcnWz')
    call winrestview(winview)
    let projectkey = matchlist(getline(projectline), '^\S\+')[0]
    let ntests = len(s:tests[projectkey].files[filename].tests)
    return printf('    %s [%d]', displayname, ntests)
  elseif line =~# '^<'
    return printf('  Error details (%d lines)', v:foldend - v:foldstart + 1)
  elseif line =~# '^>'
    return printf('            Results (%d lines)', v:foldend - v:foldstart + 1)
  elseif line =~# '^//'
    return printf('          Output (%d lines)', v:foldend - v:foldstart + 1)
  endif
  return printf('%s (%d lines)', line, v:foldend - v:foldstart + 1)
endfunction

function! OmniSharp#testrunner#Log(message) abort
  call extend(s:current.log, a:message)
endfunction


function! OmniSharp#testrunner#Run() abort
  let filename = ''
  let line = getline('.')
  if line =~# '^;'
    " Project selected - run all tests
    let projectkey = matchlist(getline('.'), '^\S\+')[0]
    let filenames = filter(keys(s:tests[projectkey].files),
    \ {_,f -> s:tests[projectkey].files[f].visible})
    call OmniSharp#actions#test#RunInFile(1, filenames)
  elseif line =~# '^    \f'
    " File selected
    let filename = trim(line)
    call OmniSharp#actions#test#RunInFile(0, filename)
    return
  else
    let test = s:utils.findTest()
    if has_key(test, 'filename')
      call OmniSharp#actions#test#Run(0, test.filename, test.name)
    endif
  endif
endfunction


function! OmniSharp#testrunner#Remove() abort
  let filename = ''
  let line = getline('.')
  if line =~# '^;'
    " Project selected - run all tests
    let projectkey = matchlist(getline('.'), '^\S\+')[0]
    let s:tests[projectkey].visible = 0
  elseif line =~# '^    \f'
    " File selected
    let filename = trim(line)
    let projectline = search('^;', 'bcnWz')
    let projectkey = matchlist(getline(projectline), '^\S\+')[0]
    let s:tests[projectkey].files[filename].visible = 0
  else
    let test = s:utils.findTest()
    let test.state = 'hidden'
  endif
  call s:buffer.paint()
endfunction


function! OmniSharp#testrunner#Navigate() abort
  if &filetype !=# 'omnisharptest' | return | endif
  let bufnr = -1
  let filename = ''
  let lnum = -1
  let col = -1
  let line = getline('.')
  if line =~# '^;'
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
      let test = s:utils.findTest()
      if has_key(test, 'filename')
        let filename = test.filename
        let lnum = test.lnum
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
  call s:buffer.paint()
endfunction


let s:buffer = {}
function! s:buffer.focus() abort
  if !has_key(s:runner, 'bufnr') | return | endif
  if getbufvar(s:runner.bufnr, '&ft') !=# 'omnisharptest' | return | endif
  " If the buffer is listed in a window in the current tab, then focus it
  for winnr in range(1, winnr('$'))
    if winbufnr(winnr) == s:runner.bufnr
      call win_gotoid(win_getid(winnr))
      return v:true
    endif
  endfor
  return v:false
endfunction

function! s:buffer.paint() abort
  if get(g:, 'OmniSharp_testrunner_banner', 1)
    let lines = self.paintbanner()
  else
    let lines = []
  endif
  for key in sort(keys(s:tests))
    let [assembly, sln] = split(key, ';')
    if !s:tests[key].visible | continue | endif
    call add(lines, key . (len(s:tests[key].errors) ? ' ERROR' : ''))
    for errorline in s:tests[key].errors
      call add(lines, '<  ' . trim(errorline, ' ', 2))
    endfor
    let loglevel = get(g:, 'OmniSharp_testrunner_loglevel', 'error')
    if loglevel ==? 'all' || (loglevel ==? 'error' && len(s:tests[key].errors))
      " The diagnostic logs (build output) are only displayed when a single file
      " is tested, otherwise multiple build outputs are intermingled
      if s:current.singlebuffer != -1
        let [ssln, sass, _] = s:utils.getProject(s:current.singlebuffer)
        if ssln ==# sln && sass ==# assembly
          if len(s:tests[key].errors) > 0 && len(s:current.log) > 1
            call add(lines, '<  ' . repeat(delimiter, 10))
          endif
          for log in s:current.log
            call add(lines, '<  ' . trim(log, ' ', 2))
          endfor
        endif
      endif
    endif
    for testfile in sort(keys(s:tests[key].files))
      if !s:tests[key].files[testfile].visible | continue | endif
      let tests = s:tests[key].files[testfile].tests
      call add(lines, '    ' . testfile)
      for name in sort(keys(tests), {a,b -> tests[a].lnum > tests[b].lnum})
        let test = tests[name]
        call extend(lines, self.painttest(test, len(lines) + 1))
      endfor
      call add(lines, '__')
    endfor
    call add(lines, '')
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

function! s:buffer.paintbanner() abort
  let lines = []
  let delimiter = get(g:, 'OmniSharp_testrunner_banner_delimeter', '─')
  call add(lines, '`' . repeat(delimiter, 80))
  call add(lines, '`    OmniSharp Test Runner')
  call add(lines, '`  ' . repeat(delimiter, 76))
  call add(lines, '`    <F1> Toggle this menu (:help omnisharp-test-runner for more)')
  call add(lines, '`    <F5> Run test or tests in file under cursor')
  call add(lines, '`    <F6> Debug test under cursor')
  call add(lines, '`    <CR> Navigate to test or stack trace')
  call add(lines, '`' . repeat(delimiter, 80))
  return lines
endfunction

function! s:buffer.painttest(test, lnum) abort
  if a:test.state ==# 'hidden'
    return []
  endif
  let lines = []
  let state = s:utils.state2char[a:test.state]
  call add(lines, printf('%s        %s', state, a:test.name))
  if state ==# '-' && !has_key(a:test, 'spintimer')
    call s:spinner.start(a:test, a:lnum)
  endif
  for messageline in get(a:test, 'message', [])
    call add(lines, '>            ' . trim(messageline, ' ', 2))
  endfor
  for stacktraceline in get(a:test, 'stacktrace', [])
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
  for outputline in get(a:test, 'output', [])
    call add(lines, '//          ' . trim(outputline, ' ', 2))
  endfor
  return lines
endfunction


function! OmniSharp#testrunner#SetBreakpoints() abort
  if !OmniSharp#util#HasVimspector()
    return s:utils.log.warn('Vimspector required to set breakpoints')
  endif
  let line = getline('.')
  " Stack trace with valid location (filename and possible line number)
  let parsed = matchlist(line, '^> \+__ .* ___ \(.*\) __ \%(line \(\d\+\)\)\?$')
  if len(parsed) && parsed[2] !=# ''
    call vimspector#SetLineBreakpoint(parsed[1], str2nr(parsed[2]))
    return s:utils.log.emphasize('Break point set')
  endif
  let test = s:utils.findTest()
  if !has_key(test, 'stacktrace')
    return s:utils.log.emphasize('No breakpoints added')
  endif
  let bps = filter(copy(test.stacktrace),
  \ "has_key(v:val, 'filename') && has_key(v:val, 'lnum')")
  for bp in bps
    call vimspector#SetLineBreakpoint(bp.filename, bp.lnum)
  endfor
  let n = len(bps)
  let message = printf('%d break point%s set', n, n == 1 ? '' : 's')
  return s:utils.log.emphasize(message)
endfunction


function! OmniSharp#testrunner#SetTests(bufferTests) abort
  let hasNew = v:false
  for buffer in a:bufferTests
    let [sln, assembly, key] = s:utils.getProject(buffer.bufnr)
    if !has_key(s:tests, key) || !s:tests[key].visible
      let hasNew = v:true
    endif
    let project = get(s:tests, key, { 'files': {}, 'errors': [] })
    let project.visible = 1
    let s:tests[key] = project
    let filename = fnamemodify(bufname(buffer.bufnr), ':p')
    let testfile = get(project.files, filename, { 'tests': {} })
    if !get(testfile, 'visible', 0)
      let hasNew = v:true
    endif
    let testfile.visible = 1
    let project.files[filename] = testfile
    for buffertest in buffer.tests
      let name = buffertest.name
      if !has_key(testfile.tests, name)
        let hasNew = v:true
      endif
      let test = get(testfile.tests, name, { 'state': 'Not run' })
      let testfile.tests[name] = test
      let test.name = name
      let test.filename = filename
      let test.assembly = assembly
      let test.sln = sln
      let test.framework = buffertest.framework
      let test.lnum = buffertest.nameRange.Start.Line
    endfor
  endfor
  let winid = win_getid()
  if hasNew
    call s:Open()
    call win_gotoid(winid)
  elseif s:buffer.focus()
    for buffer in a:bufferTests
      let filename = fnamemodify(bufname(buffer.bufnr), ':p')
      let pattern = '^    ' . substitute(filename, '/', '\\/', 'g')
      call search(pattern, 'cw')
      normal! 5zo
    endfor
    call win_gotoid(winid)
  endif
endfunction


function! s:UpdateState(bufnr, state, ...) abort
  let opts = a:0 ? a:1 : {}
  let [sln, assembly, key] = s:utils.getProject(a:bufnr)
  let s:tests[key].errors = get(opts, 'errors', [])
  let filename = fnamemodify(bufname(a:bufnr), ':p')
  let tests = s:tests[key].files[filename].tests
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
      let test = tests[testname]
      let test.state = a:state
      let test.message = get(opts, 'message', [])
      let test.stacktrace = stacktrace
      let test.output = get(opts, 'output', [])

      call setbufvar(s:runner.bufnr, '&modifiable', 1)
      let lines = getbufline(s:runner.bufnr, 1, '$')
      let pattern = '^    ' . substitute(filename, '/', '\\/', 'g')
      let fileline = match(lines, pattern) + 1
      let pattern = '^[-|*!]        ' . testname
      let testline = match(lines, pattern, fileline) + 1

      let patterns = ['^[-|*!]        \S', '^__$', '^$']
      let endline = min(
      \ filter(
      \   map(
      \     patterns,
      \     {_,pattern -> match(lines, pattern, testline)}),
      \   {_,matchline -> matchline >= testline}))
      let testlines = s:buffer.painttest(test, testline)
      call deletebufline(s:runner.bufnr, testline, endline)
      call appendbufline(s:runner.bufnr, testline - 1, testlines)
      call setbufvar(s:runner.bufnr, '&modifiable', 0)
      call setbufvar(s:runner.bufnr, '&modified', 0)
    endif
  endfor
  let winid = win_getid()
  if s:buffer.focus()
    syn sync fromstart
    call win_gotoid(winid)
  endif
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
  if s:buffer.focus()
    let displayed = getline(1) =~# '`'
    call setbufvar(s:runner.bufnr, '&modifiable', 1)
    if g:OmniSharp_testrunner_banner && !displayed
      call appendbufline(s:runner.bufnr, 0, s:buffer.paintbanner())
    elseif !g:OmniSharp_testrunner_banner && displayed
      call deletebufline(s:runner.bufnr, 1, len(s:buffer.paintbanner()))
    endif
    call setbufvar(s:runner.bufnr, '&modifiable', 0)
    call setbufvar(s:runner.bufnr, '&modified', 0)
  endif
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
  endif
  let lnum = a:lnum + (get(g:, 'OmniSharp_testrunner_banner', 1) ? 8 : 0)
  let lines = getbufline(s:runner.bufnr, lnum)
  if len(lines) == 0
    call timer_stop(a:timer)
    return
  endif
  " TODO: find the test by name, instead of line number
  let line = lines[0]
  let steps = get(g:, 'OmniSharp_testrunner_spinnersteps',
  \ get(g:, 'OmniSharp_testrunner_spinner_ascii')
  \   ? self.steps_ascii : self.steps_utf8)
  if !has_key(a:test.spinner, 'index')
    " Starting
    let line .= '  -- ' . steps[0]
    let a:test.spinner.index = 0
  elseif s:utils.state2char[a:test.state] !=# '-'
    " Stopping
    let line = substitute(line, '  -- .*$', '', '')
  else
    " Stepping
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
let s:utils.log = {}

let s:utils.state2char = {
\ 'Not run': '|',
\ 'Running': '-',
\ 'Passed': '*',
\ 'Failed': '!'
\}

function! s:utils.findTest() abort
  if &filetype !=# 'omnisharptest' | return {} | endif
  let testpattern = '[-|*!]        \S'
  let line = getline('.')
  if line =~# testpattern
    let testline = line('.')
  else
    let testline = search(testpattern, 'bcnWz')
  endif
  if testline > 0
    let testname = matchlist(getline(testline), '[-|*!]        \zs.*$')[0]
    let projectline = search('^;', 'bcnWz')
    let projectkey = matchlist(getline(projectline), '^\S\+')[0]
    let fileline = search('^    \f', 'bcnWz')
    let filename = matchlist(getline(fileline), '^    \zs.*$')[0]
    return s:tests[projectkey].files[filename].tests[testname]
  endif
  return {}
endfunction

function! s:utils.getProject(bufnr) abort
  let host = OmniSharp#GetHost(a:bufnr)
  let msbuildproject = get(host.project, 'MsBuildProject', {})
  let sln = host.sln_or_dir
  let assembly = get(msbuildproject, 'AssemblyName', '_Default')
  return [sln, assembly, printf(';%s;%s;', assembly, sln)]
endfunction

function! s:utils.log.echo(highlightGroup, message) abort
  let messageLines = type(a:message) == type([]) ? a:message : [a:message]
  execute 'echohl' a:highlightGroup
  for messageLine in messageLines
    echomsg messageLine
  endfor
  echohl None
endfunction

function! s:utils.log.emphasize(message) abort
  call self.echo('Title', a:message)
  return 1
endfunction

function! s:utils.log.warn(message) abort
  call self.echo('WarningMsg', a:message)
  return 0
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
