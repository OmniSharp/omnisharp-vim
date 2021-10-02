let s:save_cpo = &cpoptions
set cpoptions&vim

let s:runningTest = 0

function! OmniSharp#actions#test#Run(...) abort
  if !s:CheckCapabilities() | return | endif
  let bufnr = a:0 ? a:1 : bufnr('%')
  if !has_key(OmniSharp#GetHost(bufnr), 'project')
    " Initialize the test by fetching the project for the buffer - then call
    " this function again in the callback
    call OmniSharp#actions#project#Get(bufnr,
    \ function('OmniSharp#actions#test#Run', [bufnr]))
    return
  endif
  let s:runningTest = 1
  call OmniSharp#actions#codestructure#Get(bufnr,
  \ function('s:RunTest', [function('s:CBRunTest')]))
endfunction

" TODO: Can probably fold this into the above
function! OmniSharp#actions#test#Debug(...) abort
  if !s:CheckCapabilities() | return | endif
  let bufnr = a:0 ? a:1 : bufnr('%')
  if !has_key(OmniSharp#GetHost(bufnr), 'project')
    " Initialize the test by fetching the project for the buffer - then call
    " this function again in the callback
    call OmniSharp#actions#project#Get(bufnr,
    \ function('OmniSharp#actions#test#Debug', [bufnr]))
    return
  endif
  let s:runningTest = 1
  call OmniSharp#actions#codestructure#Get(bufnr,
  \ function('s:DebugTest', [function('s:CBDebugTest')]))
endfunction

function! s:CBRunTest(summary) abort
  if a:summary.pass
    if len(a:summary.locations) == 0
      echomsg 'No tests were run'
    elseif get(a:summary.locations[0], 'type', '') ==# 'W'
      echohl WarningMsg
      echomsg a:summary.locations[0].name . ': skipped'
      echohl None
    else
      echohl Title
      echomsg a:summary.locations[0].name . ': passed'
      echohl None
    endif
  else
    echomsg a:summary.locations[0].name . ': failed'
    let title = 'Test failure: ' . a:summary.locations[0].name
    call OmniSharp#locations#SetQuickfix(a:summary.locations, title)
  endif
endfunction

function! OmniSharp#actions#test#RunInFile(...) abort
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
        echohl WarningMsg | echomsg 'File not found: ' . l:file | echohl None
        continue
      endif
    endif
    call add(buffers, nr)
  endfor
  if len(buffers) == 0
    return
  endif
  let s:runningTest = 1
  call OmniSharp#util#AwaitParallel(
  \ map(copy(buffers), {i,b -> function('OmniSharp#actions#project#Get', [b])}),
  \ function('s:FindTestsInFiles', [function('s:CBRunTestsInFile'), buffers]))
endfunction

function! s:CBRunTestsInFile(summary) abort
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
    echohl Title
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
    echohl WarningMsg
  endif
  echomsg title
  echohl None
  call OmniSharp#locations#SetQuickfix(locations, title)
endfunction

function! s:RunTest(Callback, bufnr, codeElements) abort
  let tests = s:FindTests(a:codeElements)
  let currentTest = s:FindTest(tests)
  if type(currentTest) != type({})
    echohl WarningMsg | echom 'No test found' | echohl None
    let s:runningTest = 0
    return
  endif
  let project = OmniSharp#GetHost(a:bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': function('s:RunTestsRH', [a:Callback, a:bufnr, tests]),
  \ 'Parameters': {
  \   'MethodName': currentTest.name,
  \   'TestFrameworkName': currentTest.framework,
  \   'TargetFrameworkVersion': targetFramework
  \ },
  \ 'SendBuffer': 0
  \}
  echomsg 'Running test ' . currentTest.name
  call OmniSharp#stdio#Request('/v2/runtest', opts)
endfunction

function! s:DebugTest(Callback, bufnr, codeElements) abort
  let tests = s:FindTests(a:codeElements)
  let currentTest = s:FindTest(tests)
  if type(currentTest) != type({})
    echohl WarningMsg | echom 'No test found' | echohl None
    let s:runningTest = 0
    return
  endif
  let project = OmniSharp#GetHost(a:bufnr).project
  function! TestCallback() abort
    " TODO: Do we need this?
  endfunction
  call s:LaunchTestProcess(project, "FullyQualifiedName=".currentTest.name, function('TestCallback'))
  echomsg 'Debugging test ' . currentTest.name
endfunction

function! s:CBDebugTest(summary) abort
  " TODO: Do we need this?
endfunction

function! s:RunTestsRH(Callback, bufnr, tests, response) abort
  let s:runningTest = 0
  if !a:response.Success | return | endif
  if type(a:response.Body.Results) != type([])
    echohl WarningMsg
    echom 'Error: "'  . a:response.Body.Failure .
    \ '"   - this may indicate a failed build'
    echohl None
    return
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
    if result.Outcome =~? 'failed'
      let location.type = 'E'
      let location.text = location.name . ': ' . result.ErrorMessage
      let parsed = matchlist(result.ErrorStackTrace, ' in \(.\+\):line \(\d\+\)')
      if len(parsed) > 0
        let location.lnum = parsed[2]
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
    call add(summary.locations, location)
  endfor
  call a:Callback(summary)
endfunction

function! s:FindTestsInFiles(Callback, buffers, ...) abort
  call OmniSharp#util#AwaitParallel(
  \ map(copy(a:buffers), {i,b -> function('OmniSharp#actions#codestructure#Get', [b])}),
  \ function('s:RunTestsInFiles', [a:Callback]))
endfunction

function! s:RunTestsInFiles(Callback, bufferCodeStructures) abort
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
    echohl WarningMsg | echom 'No tests found' | echohl None
    let s:runningTest = 0
    return
  endif
  if g:OmniSharp_runtests_parallel
    if g:OmniSharp_runtests_echo_output
      echomsg '---- Running tests ----'
    endif
    call OmniSharp#util#AwaitParallel(Requests, a:Callback)
  else
    call OmniSharp#util#AwaitSequence(Requests, a:Callback)
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
  \   'TestFrameworkName': a:tests[0].framework,
  \   'TargetFrameworkVersion': targetFramework
  \ },
  \ 'SendBuffer': 0
  \}
  call OmniSharp#stdio#Request('/v2/runtestsinclass', opts)
endfunction

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

function! s:CheckCapabilities() abort
  if !g:OmniSharp_server_stdio
    echohl WarningMsg | echomsg 'stdio only, sorry' | echohl None
    return 0
  endif
  if g:OmniSharp_translate_cygwin_wsl
    echohl WarningMsg
    echomsg 'Tests do not work in WSL unfortunately'
    echohl None
    return 0
  endif
  if s:runningTest
    echohl WarningMsg | echomsg 'A test is already running' | echohl None
    return 0
  endif
  return 1
endfunction

function! s:LaunchTestProcess(project, filter, callback) abort
  let command = '/bin/sh -c "export VSTEST_HOST_DEBUG=1;dotnet test --filter "'.a:filter.'" '.a:project.MsBuildProject.Path
  if OmniSharp#proc#supportsNeovimJobs()
    " TODO: Finish neovim suport
  elseif OmniSharp#proc#supportsVimJobs()
    call s:RunTestCommandVim(command)
  else
    " TODO: Clean up this message
    call OmniSharp#util#EchoErr('Out of luck')
  endif
endfunction

function! s:OnVimspectorPaused() abort
  autocmd! User VimspectorDebuggerPaused
  call vimspector#Continue()
endfunction

function! s:RunTestCommandVim(command) abort
  function! VimStdout(ch, msg) abort
    " Process Id: 1086702, Name: dotnet
    let proc_string = matchstr(a:msg, "Process Id:")
    if (len(proc_string) > 0)
      let proc_id = trim(split(split(a:msg, ':')[1], ',')[0], ' ')
      echom proc_id
      autocmd User VimspectorDebuggerPaused call s:OnVimspectorPaused()
      " if https://github.com/puremourning/vimspector/pull/473 is merge, we
      " can use this.
      call vimspector#LaunchWithConfigurations({
      \  "attach": {
      \    "adapter": "netcoredbg",
      \    "configuration": {
      \      "request": "attach",
      \      "processId": proc_id
      \    }
      \  }
      \})
      " Otherwise we have to use this
      " call vimspector#LaunchWithSettings({
      "   \ "configuration" : "attach",
      "   \ "pid" : proc_id
      " \ })
      " sleep 10
    endif
    echom a:msg
  endfunction
  function! VimStdErr(ch, msg) abort
    echom a:msg
  endfunction
  function! VimCloseCb(ch) abort
    let s:runningTest = 0
    call vimspector#Reset()
    echom "Closed"
  endfunction
  let job = job_start(a:command, {
    \ "mode" : "nl",
    \ "out_cb" : function("VimStdout"),
    \ "err_cb" : function("VimStdErr"),
    \ "close_cb" : function("VimCloseCb")
  \ })
  call ch_close_in(job)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
