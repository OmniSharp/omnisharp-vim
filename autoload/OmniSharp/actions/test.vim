let s:save_cpo = &cpoptions
set cpoptions&vim

let s:debug = {}
let s:debug.process = {}
let s:run = {}
let s:run.running = 0
let s:run.single = {}
let s:run.multiple = {}
let s:utils = {}
let s:utils.init = {}
let s:utils.log = {}

function! OmniSharp#actions#test#Debug(nobuild) abort
  if !s:utils.capabilities() | return | endif
  let s:nobuild = a:nobuild
  if !OmniSharp#util#HasVimspector()
    return s:utils.log.warn('Vimspector required to debug tests')
  endif
  call s:utils.initialize([bufnr('%')], s:debug.prepare)
endfunction

function! s:debug.prepare(bufferTests) abort
  let bufnr = a:bufferTests[0].bufnr
  let tests = a:bufferTests[0].tests
  let currentTest = s:utils.findTest(tests)
  if type(currentTest) != type({})
    return s:utils.log.warn('No test found')
  endif
  let project = OmniSharp#GetHost(bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': funcref('s:debug.launch', [bufnr, currentTest.name]),
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

function! s:debug.launch(bufnr, testname, response) abort
  let args = split(substitute(a:response.Body.Arguments, '\"', '', 'g'), ' ')
  let cmd = a:response.Body.FileName
  let testhost = [cmd] + args
  if !s:debug.process.start(testhost) | return | endif
  let s:run.running = 1
  call OmniSharp#testrunner#StateRunning(a:bufnr, a:testname)
  let s:debug.bufnr = a:bufnr
  let s:omnisharp_pre_debug_cwd = getcwd()
  call vimspector#LaunchWithConfigurations({
  \ 'attach': {
  \   'adapter': 'netcoredbg',
  \   'configuration': {
  \     'request': 'attach',
  \     'processId': s:debug.process.pid
  \   }
  \ }
  \})
  let project_dir = fnamemodify(OmniSharp#GetHost(a:bufnr).sln_or_dir, ':p:h')
  execute 'tcd' project_dir
  let opts = {
  \ 'ResponseHandler': s:debug.complete,
  \ 'Parameters': {
  \   'TargetProcessId': s:debug.process.pid
  \ }
  \}
  echomsg 'Launching debugged test'
  call OmniSharp#stdio#Request('/v2/debugtest/launch', opts)
endfunction

function! s:debug.complete(response) abort
  if !a:response.Success
    call s:utils.log.warn(['Error debugging unit test', a:response.Message])
  endif
  call OmniSharp#testrunner#StateSkipped(s:debug.bufnr)
endfunction

function! s:debug.process.start(command) abort
  if OmniSharp#proc#supportsNeovimJobs()
    let jobid = jobstart(a:command, { 'on_exit': self.closed })
    let self.pid = jobpid(jobid)
  elseif OmniSharp#proc#supportsVimJobs()
    let job = job_start(a:command, { 'close_cb': self.closed })
    let self.pid = split(job, ' ')[1]
  else
    return s:utils.log.warn('Cannot launch test process.')
  endif
  return 1
endfunction

function! s:debug.process.closed(...) abort
  call OmniSharp#stdio#Request('/v2/debugtest/stop', {})
  let s:run.running = 0
  call vimspector#Reset()
  execute 'tcd' s:omnisharp_pre_debug_cwd
  unlet s:omnisharp_pre_debug_cwd
endfunction


function! OmniSharp#actions#test#Run(nobuild) abort
  if !s:utils.capabilities() | return | endif
  let s:nobuild = a:nobuild
  call s:utils.initialize([bufnr('%')], s:run.single.test)
endfunction

function! s:run.single.test(bufferTests) abort
  let bufnr = a:bufferTests[0].bufnr
  let tests = a:bufferTests[0].tests
  let currentTest = s:utils.findTest(tests)
  if type(currentTest) != type({})
    return s:utils.log.warn('No test found')
  endif
  let s:run.running = 1
  call OmniSharp#testrunner#StateRunning(bufnr, currentTest.name)
  let project = OmniSharp#GetHost(bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': funcref('s:run.process', [s:run.single.complete, bufnr, tests]),
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

function! s:run.single.complete(summary) abort
  if a:summary.pass && len(a:summary.locations) == 0
    echomsg 'No tests were run'
    " Do we ever reach here?
    " call OmniSharp#testrunner#StateSkipped(bufnr)
  endif
  let location = a:summary.locations[0]
  call OmniSharp#testrunner#StateComplete(location)
  if a:summary.pass
    if get(location, 'type', '') ==# 'W'
      call s:utils.log.warn(location.name . ': skipped')
    else
      call s:utils.log.emphasize(location.name . ': passed')
    endif
  else
    echomsg location.name . ': failed'
    let title = 'Test failure: ' . location.name
    if get(g:, 'OmniSharp_test_quickfix', 1) == 0 | return | endif
    let what = {}
    if len(a:summary.locations) > 1
      let what.quickfixtextfunc = {info->
      \ map(getqflist({'id': info.id, 'items': 1}).items, {_,i -> i.text})}
    endif
    call OmniSharp#locations#SetQuickfix(a:summary.locations, title, what)
  endif
endfunction


function! OmniSharp#actions#test#RunInFile(nobuild, ...) abort
  let s:nobuild = a:nobuild
  if !s:utils.capabilities() | return | endif
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
        call s:utils.log.warn('File not found: ' . l:file)
        continue
      endif
    endif
    call add(buffers, nr)
  endfor
  if len(buffers) == 0 | return | endif
  call s:utils.initialize(buffers, s:run.multiple.prepare)
endfunction

function! s:run.multiple.prepare(bufferTests) abort
  let Requests = []
  for btests in a:bufferTests
    let bufnr = btests.bufnr
    let tests = btests.tests
    let testnames = map(copy(tests), {_,t -> t.name})
    if len(tests)
      call OmniSharp#testrunner#StateRunning(bufnr, testnames)
      call add(Requests, funcref('s:run.multiple.inBuffer', [bufnr, tests]))
    endif
  endfor
  if len(Requests) == 0 | return s:utils.log.warn('No tests found') | endif
  let s:run.running = 1
  if g:OmniSharp_runtests_parallel
    if g:OmniSharp_runtests_echo_output
      echomsg '---- Running tests ----'
    endif
    call OmniSharp#util#AwaitParallel(Requests, s:run.multiple.complete)
  else
    call OmniSharp#util#AwaitSequence(Requests, s:run.multiple.complete)
  endif
endfunction

function! s:run.multiple.inBuffer(bufnr, tests, Callback) abort
  if !g:OmniSharp_runtests_parallel && g:OmniSharp_runtests_echo_output
    echomsg '---- Running tests: ' . bufname(a:bufnr) . ' ----'
  endif
  let project = OmniSharp#GetHost(a:bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': funcref('s:run.process', [a:Callback, a:bufnr, a:tests]),
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

function! s:run.multiple.complete(summary) abort
  let pass = 1
  let locations = []
  for summary in a:summary
    call extend(locations, summary.locations)
    if !summary.pass
      let pass = 0
    endif
  endfor
  for location in locations
    call OmniSharp#testrunner#StateComplete(location)
  endfor
  if pass
    let title = len(locations) . ' tests passed'
    call s:utils.log.emphasize(title)
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
    call s:utils.log.warn(title)
  endif
  if get(g:, 'OmniSharp_test_quickfix', 1) == 0 | return | endif
  call OmniSharp#locations#SetQuickfix(locations, title)
endfunction


" Response handler used when running a single test, or multiple tests in files
function! s:run.process(Callback, bufnr, tests, response) abort
  let s:run.running = 0
  if !a:response.Success | return | endif
  if type(a:response.Body.Results) != type([])
    return s:utils.log.warn('Error: "' . a:response.Body.Failure .
    \ '"   - this may indicate a failed build')
  endif
  let summary = {
  \ 'pass': a:response.Body.Pass,
  \ 'locations': []
  \}
  for result in a:response.Body.Results
    " Strip namespace and classname from test method name
    let location = {
    \ 'bufnr': a:bufnr,
    \ 'fullname': result.MethodName,
    \ 'filename': bufname(a:bufnr),
    \ 'name': substitute(result.MethodName, '^.*\.', '', '')
    \}
    let locations = [location]
    " Write any standard output to message-history
    if len(get(result, 'StandardOutput', []))
      let location.output = []
      echomsg 'Standard output from test ' . location.name . ':'
      for output in result.StandardOutput
        for line in split(trim(output), '\r\?\n', 1)
          call add(location.output, line)
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
      let test = s:utils.findTest(a:tests, result.MethodName)
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


function! OmniSharp#actions#test#Validate() abort
  return s:utils.capabilities()
endfunction

function! s:utils.capabilities() abort
  if !g:OmniSharp_server_stdio
    return self.log.warn('stdio only, sorry')
  endif
  if g:OmniSharp_translate_cygwin_wsl
    return self.log.warn('Tests do not work in WSL unfortunately')
  endif
  if s:run.running
    return self.log.warn('A test is already running')
  endif
  return 1
endfunction

" Find all of the test methods in a CodeStructure response
function! s:utils.extractTests(codeElements) abort
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
    call extend(tests, self.extractTests(get(element, 'Children', [])))
  endfor
  return tests
endfunction

" Find the test in a list of tests that matches the current cursor position
function! s:utils.findTest(tests, ...) abort
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

" For the given buffers, fetch the project structures, then fetch the buffer
" code structures. All operations are performed asynchronously, and the
" a:Callback is called when all buffer code structures have been fetched.
function! s:utils.initialize(buffers, Callback) abort
  call s:utils.init.await(a:buffers, 'OmniSharp#actions#project#Get',
  \ funcref('s:utils.init.await', [a:buffers, 'OmniSharp#actions#codestructure#Get',
  \   funcref('s:utils.init.extract', [a:Callback])]))
endfunction

function! s:utils.init.await(buffers, functionName, Callback, ...) abort
  let Funcs = map(copy(a:buffers), {i,b -> function(a:functionName, [b])})
  call OmniSharp#util#AwaitParallel(Funcs, a:Callback)
endfunction

function! s:utils.init.extract(Callback, codeStructures) abort
  let bufferTests = map(a:codeStructures, {i, cs -> {
  \ 'bufnr': cs[0],
  \ 'tests': s:utils.extractTests(cs[1])
  \}})
  call OmniSharp#testrunner#SetTests(bufferTests)
  call a:Callback(bufferTests)
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
