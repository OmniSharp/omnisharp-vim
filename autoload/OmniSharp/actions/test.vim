let s:save_cpo = &cpoptions
set cpoptions&vim

let s:runningTest = 0

function! OmniSharp#actions#test#Debug(nobuild) abort
  if !s:CheckCapabilities() | return | endif
  let s:nobuild = a:nobuild
  if !OmniSharp#util#HasVimspector()
    return s:Warn('Vimspector required to debug tests')
  endif
  call s:InitializeTestBuffers([bufnr('%')], function('s:DebugTest'))
endfunction

function! s:DebugTest(bufferCodeStructures) abort
  let bufnr = a:bufferCodeStructures[0][0]
  let codeElements = a:bufferCodeStructures[0][1]
  let tests = s:FindTests(codeElements)
  let currentTest = s:FindTest(tests)
  if type(currentTest) != type({})
    let s:runningTest = 0
    return s:Warn('No test found')
  endif
  let project = OmniSharp#GetHost(bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': function('s:DebugTestsRH', [bufnr, tests]),
  \ 'Parameters': {
  \   'MethodName': currentTest.name,
  \   'NoBuild': get(s:, 'nobuild', 0),
  \   'TestFrameworkName': currentTest.framework,
  \   'TargetFrameworkVersion': targetFramework
  \ },
  \ 'SendBuffer': 0
  \}
  echomsg 'Debugging test ' . currentTest.name
  call OmniSharp#stdio#Request('/v2/debugtest/getstartinfo', opts)
endfunction

function! s:DebugTestsRH(bufnr, tests, response) abort
  let testhost = [a:response.Body.FileName] + split(substitute(a:response.Body.Arguments, '\"', '', 'g'), ' ')
  let testhost_job_pid = s:StartTestProcess(testhost)
  let g:testhost_job_pid = testhost_job_pid

  let host = OmniSharp#GetHost()
  let s:omnisharp_pre_debug_cwd = getcwd()
  let new_cwd = fnamemodify(host.sln_or_dir, ':p:h')
  call vimspector#LaunchWithConfigurations({
  \  'attach': {
  \    'adapter': 'netcoredbg',
  \    'configuration': {
  \      'request': 'attach',
  \      'processId': testhost_job_pid
  \    }
  \  }
  \})
  execute 'tcd' new_cwd
  let opts = {
  \ 'ResponseHandler': function('s:DebugComplete'),
  \ 'Parameters': {
  \   'TargetProcessId': testhost_job_pid
  \ }
  \}
  echomsg 'Launching debugged test'
  call OmniSharp#stdio#Request('/v2/debugtest/launch', opts)
endfunction

function! s:DebugComplete(response) abort
  if !a:response.Success
    call s:Warn(['Error debugging unit test', a:response.Message])
  endif
endfunction

function! s:StartTestProcess(command) abort
  function! s:TestProcessClosed(...) abort
    call OmniSharp#stdio#Request('/v2/debugtest/stop', {})
    let s:runningTest = 0
    call vimspector#Reset()
    execute 'tcd' s:omnisharp_pre_debug_cwd
    unlet s:omnisharp_pre_debug_cwd
  endfunction
  if OmniSharp#proc#supportsNeovimJobs()
    let job = jobpid(jobstart(a:command, {
      \ 'on_exit': function('s:TestProcessClosed')
    \ }))
  elseif OmniSharp#proc#supportsVimJobs()
    let job = split(job_start(a:command, {
      \ 'close_cb': function('s:TestProcessClosed')
    \ }), ' ',)[1]
  else
    call s:Warn('Cannot launch test process.')
  endif
  return job
endfunction

function! OmniSharp#actions#test#Run(nobuild) abort
  if !s:CheckCapabilities() | return | endif
  let s:nobuild = a:nobuild
  call s:InitializeTestBuffers([bufnr('%')], function('s:RunTest'))
endfunction

function! s:RunTest(bufferCodeStructures) abort
  let bufnr = a:bufferCodeStructures[0][0]
  let codeElements = a:bufferCodeStructures[0][1]
  let tests = s:FindTests(codeElements)
  let currentTest = s:FindTest(tests)
  if type(currentTest) != type({})
    let s:runningTest = 0
    return s:Warn('No test found')
  endif
  let project = OmniSharp#GetHost(bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': function('s:RunTestsRH', [function('s:RunComplete'), bufnr, tests]),
  \ 'Parameters': {
  \   'MethodName': currentTest.name,
  \   'NoBuild': get(s:, 'nobuild', 0),
  \   'TestFrameworkName': currentTest.framework,
  \   'TargetFrameworkVersion': targetFramework
  \ },
  \ 'SendBuffer': 0
  \}
  echomsg 'Running test ' . currentTest.name
  call OmniSharp#stdio#Request('/v2/runtest', opts)
endfunction

function! s:RunComplete(summary) abort
  if a:summary.pass
    if len(a:summary.locations) == 0
      echomsg 'No tests were run'
    elseif get(a:summary.locations[0], 'type', '') ==# 'W'
      call s:Warn(a:summary.locations[0].name . ': skipped')
    else
      call s:Emphasize(a:summary.locations[0].name . ': passed')
    endif
  else
    echomsg a:summary.locations[0].name . ': failed'
    let title = 'Test failure: ' . a:summary.locations[0].name
    let what = {}
    if len(a:summary.locations) > 1
      let what = {'quickfixtextfunc': function('s:QuickfixTextFuncStackTrace')}
    endif
    call OmniSharp#locations#SetQuickfix(a:summary.locations, title, what)
  endif
endfunction

function! OmniSharp#actions#test#RunInFile(nobuild, ...) abort
  let s:nobuild = a:nobuild
  if !s:CheckCapabilities() | return | endif
  if a:0 && type(a:1) == type([])
    let files = a:1
  elseif a:0 && type(a:1) == type('')
    let files = a:000
  else
    let files = [expand('%:p')]
  endif
  let files = map(copy(files), {i,f -> fnamemodify(f, ':p')})
  let buffers = []
  for l:file in files
    let l:file = OmniSharp#util#TranslatePathForServer(l:file)
    let nr = bufnr(l:file)
    if nr == -1
      if filereadable(l:file)
        let nr = bufadd(l:file)
      else
        call s:Warn('File not found: ' . l:file)
        continue
      endif
    endif
    call add(buffers, nr)
  endfor
  if len(buffers) == 0
    return
  endif
  let s:runningTest = 1
  call s:InitializeTestBuffers(buffers, function('s:RunTestsInFiles'))
endfunction

function! s:RunTestsInFiles(bufferCodeStructures) abort
  let Requests = []
  for bcs in a:bufferCodeStructures
    let bufnr = bcs[0]
    let codeElements = bcs[1]
    let tests = s:FindTests(codeElements)
    if len(tests)
      call add(Requests, function('s:RunTestsInFile', [bufnr, tests]))
    endif
  endfor
  if len(Requests) == 0
    let s:runningTest = 0
    return s:Warn('No tests found')
  endif
  if g:OmniSharp_runtests_parallel
    if g:OmniSharp_runtests_echo_output
      echomsg '---- Running tests ----'
    endif
    call OmniSharp#util#AwaitParallel(Requests, function('s:RunInFileComplete'))
  else
    call OmniSharp#util#AwaitSequence(Requests, function('s:RunInFileComplete'))
  endif
endfunction

function! s:RunTestsInFile(bufnr, tests, Callback) abort
  if !g:OmniSharp_runtests_parallel && g:OmniSharp_runtests_echo_output
    echomsg '---- Running tests: ' . bufname(a:bufnr) . ' ----'
  endif
  let project = OmniSharp#GetHost(a:bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': function('s:RunTestsRH', [a:Callback, a:bufnr, a:tests]),
  \ 'BufNum': a:bufnr,
  \ 'Parameters': {
  \   'MethodNames': map(copy(a:tests), {i,t -> t.name}),
  \   'NoBuild': get(s:, 'nobuild', 0),
  \   'TestFrameworkName': a:tests[0].framework,
  \   'TargetFrameworkVersion': targetFramework
  \ },
  \ 'SendBuffer': 0
  \}
  call OmniSharp#stdio#Request('/v2/runtestsinclass', opts)
endfunction

function! s:RunInFileComplete(summary) abort
  let pass = 1
  let locations = []
  for summary in a:summary
    call extend(locations, summary.locations)
    if !summary.pass
      let pass = 0
    endif
  endfor
  if pass
    let title = len(locations) . ' tests passed'
    call s:Emphasize(title)
  else
    let passed = 0
    let noStackTrace = 0
    for location in locations
      if !has_key(location, 'type')
        let passed += 1
      endif
      if has_key(location, 'noStackTrace')
        let noStackTrace = 1
      endif
    endfor
    let title = passed . ' of ' . len(locations) . ' tests passed'
    if noStackTrace
      let title .= '. Check :messages for details.'
    endif
    call s:Warn(title)
  endif
  call OmniSharp#locations#SetQuickfix(locations, title)
endfunction

" Response handler used when running a single test, or tests in files
function! s:RunTestsRH(Callback, bufnr, tests, response) abort
  let s:runningTest = 0
  if !a:response.Success | return | endif
  if type(a:response.Body.Results) != type([])
    return s:Warn('Error: "' . a:response.Body.Failure .
    \ '"   - this may indicate a failed build')
  endif
  let summary = {
  \ 'pass': a:response.Body.Pass,
  \ 'locations': []
  \}
  for result in a:response.Body.Results
    " Strip namespace and classname from test method name
    let location = {
    \ 'filename': bufname(a:bufnr),
    \ 'name': substitute(result.MethodName, '^.*\.', '', '')
    \}
    let locations = [location]
    " Write any standard output to message-history
    if len(get(result, 'StandardOutput', []))
      echomsg 'Standard output from test ' . location.name . ':'
      for output in result.StandardOutput
        for line in split(trim(output), '\r\?\n', 1)
          echomsg '  ' . line
        endfor
      endfor
    endif
    if result.Outcome =~? 'failed'
      let location.type = 'E'
      let location.text = location.name . ': ' . result.ErrorMessage
      let st = result.ErrorStackTrace
      let parsed = matchlist(st, '.* in \(.\+\):line \(\d\+\)')
      if len(parsed) > 0
        let location.lnum = parsed[2]
        " When a single test is run, include the stack trace as quickfix entries
        if a:response.Command ==# '/v2/runtest'
          " Parse the stack trace and create quickfix locations
          let st = substitute(st, '.*\zs at .\+ in .\+:line \d\+.*', '', '')
          let parsed = matchlist(st, '.*\( at .\+ in \(.\+\):line \(\d\+\)\)')
          while len(parsed) > 0
            call add(locations, {
            \ 'filename': parsed[2],
            \ 'lnum': parsed[3],
            \ 'type': 'E',
            \ 'text': parsed[1]
            \})
            let st = substitute(st, '.*\zs at .\+ in .\+:line \d\+.*', '', '')
            let parsed = matchlist(st, '.*\( at .\+ in \(.\+\):line \(\d\+\)\)')
          endwhile
        endif
      else
        " An error occurred outside the test. This can occur with .e.g. nunit
        " when the class constructor throws an exception.
        " Add an extra property, which can be used later to warn the user to
        " check :messages for details.
        let location.noStackTrace = 1
      endif
    elseif result.Outcome =~? 'skipped'
      let location.type = 'W'
      let location.text = location.name . ': ' . result.Outcome
    else
      let location.text = location.name . ': ' . result.Outcome
    endif
    if !has_key(location, 'lnum')
      " Success, or unexpected test failure.
      let test = s:FindTest(a:tests, result.MethodName)
      if type(test) == type({})
        let location.lnum = test.nameRange.Start.Line
        let location.col = test.nameRange.Start.Column
        let location.vcol = 0
      endif
    endif
    for loc in locations
      call add(summary.locations, loc)
    endfor
  endfor
  call a:Callback(summary)
endfunction

" Utilities
" =========

function! s:CheckCapabilities() abort
  if !g:OmniSharp_server_stdio
    return s:Warn('stdio only, sorry')
  endif
  if g:OmniSharp_translate_cygwin_wsl
    return s:Warn('Tests do not work in WSL unfortunately')
  endif
  if s:runningTest
    return s:Warn('A test is already running')
  endif
  return 1
endfunction

function! s:EchoMessages(highlightGroup, message) abort
  let messageLines = type(a:message) == type([]) ? a:message : [a:message]
  execute 'echohl' a:highlightGroup
  for messageLine in messageLines
    echomsg messageLine
  endfor
  echohl None
endfunction

function! s:Emphasize(message) abort
  call s:EchoMessages('Title', a:message)
  return 1
endfunction

" Find the test in a list of tests that matches the current cursor position
function! s:FindTest(tests, ...) abort
  for test in a:tests
    if a:0
      if test.name ==# a:1
        return test
      endif
    else
      if line('.') >= test.range.Start.Line && line('.') <= test.range.End.Line
        return test
      endif
    endif
  endfor
  return 0
endfunction

" Find all of the test methods in a CodeStructure response
function! s:FindTests(codeElements) abort
  if type(a:codeElements) != type([]) | return [] | endif
  let tests = []
  for element in a:codeElements
    if has_key(element, 'Properties')
    \ && type(element.Properties) == type({})
    \ && has_key(element.Properties, 'testMethodName')
    \ && has_key(element.Properties, 'testFramework')
      call add(tests, {
      \ 'name': element.Properties.testMethodName,
      \ 'framework': element.Properties.testFramework,
      \ 'range': element.Ranges.full,
      \ 'nameRange': element.Ranges.name,
      \})
    endif
    call extend(tests, s:FindTests(get(element, 'Children', [])))
  endfor
  return tests
endfunction

" For the given buffers, fetch the project structures, then fetch the buffer
" code structures. All operations are performed asynchronously, and the
" a:Callback is called when all buffer code structures have been fetched.
function! s:InitializeTestBuffers(buffers, Callback) abort
  function! s:AwaitForBuffers(buffers, functionName, AwaitCallback, ...) abort
    call OmniSharp#util#AwaitParallel(
    \ map(copy(a:buffers), {i,b -> function(a:functionName, [b])}),
    \ a:AwaitCallback)
  endfunction
  call s:AwaitForBuffers(a:buffers, 'OmniSharp#actions#project#Get',
  \ function('s:AwaitForBuffers',
  \   [a:buffers, 'OmniSharp#actions#codestructure#Get', a:Callback]))
endfunction

function! s:Warn(message) abort
  call s:EchoMessages('WarningMsg', a:message)
  return 0
endfunction

function! s:QuickfixTextFuncStackTrace(info) abort
  let items = getqflist({'id' : a:info.id, 'items' : 1}).items
  return map(items, {_,i -> i.text})
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
