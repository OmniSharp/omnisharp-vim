let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = get(s:, 'nextseq', 1001)
let s:requests = get(s:, 'requests', {})
let s:pendingRequests = get(s:, 'pendingRequests', {})

function! s:HandleServerEvent(job, res) abort
  if has_key(a:res, 'Body') && type(a:res.Body) == type({})
    if !a:job.loaded

      " Listen for server-loaded events
      "-------------------------------------------------------------------------
      if g:OmniSharp_server_stdio_quickload
        " Quick load: Mark server as loaded as soon as configuration is finished
        let message = get(a:res.Body, 'Message', '')
        if message ==# 'Configuration finished.'
          let a:job.loaded = 1
          silent doautocmd <nomodeline> User OmniSharpReady
          call s:ReplayRequests()
        endif
      else
        " Complete load: Wait for all projects to be loaded before marking
        " server as loaded
        if !has_key(a:job, 'loading_timeout')
          " Create a timeout to mark a job as loaded after 30 seconds despite
          " not receiving the expected server events.
          let a:job.loading_timeout = timer_start(
          \ g:OmniSharp_server_loading_timeout * 1000,
          \ function('s:ServerLoadTimeout', [a:job]))
        endif
        if !has_key(a:job, 'loading')
          let a:job.loading = []
        endif
        let name = get(a:res.Body, 'Name', '')
        let message = get(a:res.Body, 'Message', '')
        if name ==# 'OmniSharp.MSBuild.ProjectManager'
          let project = matchstr(message, '''\zs.*\ze''')
          if message =~# '^Queue project'
            call add(a:job.loading, project)
          endif
          if message =~# '^Successfully loaded project'
          \ || message =~# '^Failed to load project'
            if message[0] ==# 'F'
              echom 'Failed to load project: ' . project
            endif
            call filter(a:job.loading, {idx,val -> val !=# project})
            if len(a:job.loading) == 0
              if g:OmniSharp_server_display_loading
                let elapsed = reltimefloat(reltime(a:job.start_time))
                echomsg printf('Loaded server for %s in %.1fs',
                \ a:job.sln_or_dir, elapsed)
              endif
              let a:job.loaded = 1
              silent doautocmd <nomodeline> User OmniSharpReady

              " TODO: Remove this delay once we have better information about
              " when the server is completely initialised:
              " https://github.com/OmniSharp/omnisharp-roslyn/issues/1521
              call timer_start(1000, function('s:ReplayRequests'))
              " call s:ReplayRequests()

              unlet a:job.loading
              call timer_stop(a:job.loading_timeout)
              unlet a:job.loading_timeout
            endif
          endif
        endif
      endif

    else

      " Server is loaded, listen for diagnostics
      "-------------------------------------------------------------------------
      if get(a:res, 'Event', '') ==# 'Diagnostic'
        if has_key(g:, 'OmniSharp_ale_diagnostics_requested')
          for result in get(a:res.Body, 'Results', [])
            let fname = OmniSharp#util#TranslatePathForClient(result.FileName)
            let bufinfo = getbufinfo(fname)
            if len(bufinfo) == 0 || !has_key(bufinfo[0], 'bufnr')
              continue
            endif
            let bufnr = bufinfo[0].bufnr
            call ale#other_source#StartChecking(bufnr, 'OmniSharp')
            let opts = { 'BufNum': bufnr }
            let quickfixes = OmniSharp#locations#Parse(result.QuickFixes)
            call ale#sources#OmniSharp#ProcessResults(opts, quickfixes)
          endfor
        endif
      elseif get(a:res, 'Event', '') ==# 'TestMessage'
        " Diagnostics received while running tests
        let lines = split(a:res.Body.Message, '\n')
        for line in lines
          if get(a:res.Body, 'MessageLevel', '') ==# 'error'
            echohl WarningMsg | echomsg line | echohl None
          elseif g:OmniSharp_runtests_echo_output
            echomsg line
          endif
        endfor
      endif

    endif
  endif
endfunction

function! s:ServerLoadTimeout(job, timer) abort
  if g:OmniSharp_server_display_loading
    echomsg printf('Server load notification for %s not received after %d seconds - continuing.',
    \ a:job.sln_or_dir, g:OmniSharp_server_loading_timeout)
  endif
  let a:job.loaded = 1
  unlet a:job.loading
  unlet a:job.loading_timeout
endfunction

let s:logfile = expand('<sfile>:p:h:h:h') . '/log/stdio.log'
function! s:Log(message, loglevel) abort
  let logit = 0
  if g:OmniSharp_loglevel ==? 'debug'
    " Log everything
    let logit = 1
  elseif g:OmniSharp_loglevel ==? 'info'
    let logit = a:loglevel ==# 'info'
  else
    " g:OmniSharp_loglevel ==? 'none'
  endif
  if logit
    call writefile([a:message], s:logfile, 'a')
  endif
endfunction

function! OmniSharp#stdio#Request(command, opts) abort
  if has_key(a:opts, 'UsePreviousPosition')
    let [bufnr, lnum, cnum] = s:lastPosition
  elseif has_key(a:opts, 'BufNum') && a:opts.BufNum != bufnr('%')
    let bufnr = a:opts.BufNum
    let lnum = 1
    let cnum = 1
  else
    let bufnr = bufnr('%')
    let lnum = line('.')
    let cnum = col('.')
  endif
  if has_key(a:opts, 'SavePosition')
    let s:lastPosition = [bufnr, lnum, cnum]
  endif
  let metadata_filename = get(b:, 'OmniSharp_metadata_filename', v:null)
  let is_metadata = type(metadata_filename) == type('')
  if is_metadata
    let filename = metadata_filename
    let send_buffer = 0
  else
    let filename = OmniSharp#util#TranslatePathForServer(
    \ fnamemodify(bufname(bufnr), ':p'))
    let send_buffer = get(a:opts, 'SendBuffer', 1)
  endif
  let lines = getbufline(bufnr, 1, '$')
  if has_key(a:opts, 'OverrideBuffer')
    let lines[a:opts.OverrideBuffer.LineNr - 1] = a:opts.OverrideBuffer.Line
    let cnum = a:opts.OverrideBuffer.Col
  endif
  let tmp = join(lines, '')
  " Unique string separator which must not exist in the buffer
  let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
  while stridx(tmp, sep) >= 0
    let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
  endwhile
  let buffer = join(lines, sep)

  let body = {
  \ 'Arguments': {
  \   'FileName': filename,
  \   'Line': lnum,
  \   'Column': cnum,
  \ }
  \}

  if send_buffer
    let body.Arguments.Buffer = buffer
  endif
  return s:RawRequest(body, a:command, a:opts, sep)
endfunction

function! s:RawRequest(body, command, opts, ...) abort
  let sep = a:0 ? a:1 : ''

  let job = OmniSharp#GetHost().job
  if type(job) != type({}) || !has_key(job, 'job_id') || !job.loaded
    if has_key(a:opts, 'ReplayOnLoad') && !has_key(s:pendingRequests, a:command)
      " This request should be replayed when the server is fully loaded
      let s:pendingRequests[a:command] = a:opts
    endif
    return 0
  endif
  let job_id = job.job_id
  call s:Log(job_id . '  Request: ' . a:command, 'debug')

  let a:body['Command'] = a:command
  let a:body['Seq'] = s:nextseq
  let a:body['Type'] = 'request'
  if has_key(a:opts, 'Parameters')
    call extend(a:body.Arguments, a:opts.Parameters, 'force')
  endif
  if sep !=# ''
    let encodedBody = substitute(json_encode(a:body), sep, '\\r\\n', 'g')
  else
    let encodedBody = json_encode(a:body)
  endif

  let s:requests[s:nextseq] = { 'Seq': s:nextseq }
  if has_key(a:opts, 'ResponseHandler')
    let s:requests[s:nextseq].ResponseHandler = a:opts.ResponseHandler
  endif
  let s:nextseq += 1
  call s:Log(encodedBody, 'debug')
  if has('nvim')
    call chansend(job_id, encodedBody . "\n")
  else
    call ch_sendraw(job_id, encodedBody . "\n")
  endif
  return 1
endfunction

function! s:ReplayRequests(...) abort
  for key in keys(s:pendingRequests)
    call OmniSharp#stdio#Request(key, s:pendingRequests[key])
    unlet s:pendingRequests[key]
  endfor
endfunction

" Call a list of async functions in parallel, and wait for them all to complete
" before calling the OnAllComplete function.
function! s:AwaitParallel(Funcs, OnAllComplete) abort
  let state = {
  \ 'count': 0,
  \ 'target': len(a:Funcs),
  \ 'results': [],
  \ 'OnAllComplete': a:OnAllComplete
  \}
  for Func in a:Funcs
    call Func(function('s:AwaitFuncComplete', [state]))
  endfor
endfunction

" Call a list of async functions in sequence, and wait for them all to complete
" before calling the OnAllComplete function.
function! s:AwaitSequence(Funcs, OnAllComplete, ...) abort
  if a:0
    let state = a:1
  else
    let state = {
    \ 'count': 0,
    \ 'target': len(a:Funcs),
    \ 'results': [],
    \ 'OnAllComplete': a:OnAllComplete
    \}
  endif

  let Func = remove(a:Funcs, 0)
  let state.OnComplete = function('s:AwaitSequence', [a:Funcs, a:OnAllComplete])
  call Func(function('s:AwaitFuncComplete', [state]))
endfunction

function! s:AwaitFuncComplete(state, ...) abort
  if a:0 == 1
    call add(a:state.results, a:1)
  elseif a:0 > 1
    call add(a:state.results, a:000)
  endif
  let a:state.count += 1
  if a:state.count == a:state.target
    call a:state.OnAllComplete(a:state.results)
  elseif has_key(a:state, 'OnComplete')
    call a:state.OnComplete(a:state)
  endif
endfunction

function! OmniSharp#stdio#GetLogFile() abort
  return s:logfile
endfunction

function! OmniSharp#stdio#HandleResponse(job, message) abort
  try
    let res = json_decode(a:message)
  catch
    call s:Log(a:job.job_id . '  ' . a:message, 'info')
    call s:Log(a:job.job_id . '  JSON error: ' . v:exception, 'info')
    return
  endtry
  let loglevel =  get(res, 'Event', '') ==? 'log' ? 'info' : 'debug'
  call s:Log(a:job.job_id . '  ' . a:message, loglevel)
  if get(res, 'Type', '') ==# 'event'
    call s:HandleServerEvent(a:job, res)
    return
  endif
  if !has_key(res, 'Request_seq') || !has_key(s:requests, res.Request_seq)
    return
  endif
  let req = remove(s:requests, res.Request_seq)
  if has_key(req, 'ResponseHandler')
    if has_key(req, 'Request')
      call req.ResponseHandler(res, req.Request)
    else
      call req.ResponseHandler(res)
    endif
  endif
endfunction


function! OmniSharp#stdio#CodeCheck(opts, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeCheckRH', [a:Callback]),
  \ 'ReplayOnLoad': 1
  \}
  call extend(opts, a:opts, 'force')
  call OmniSharp#stdio#Request('/codecheck', opts)
endfunction

function! s:CodeCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse(a:response.Body.QuickFixes))
endfunction


function! OmniSharp#stdio#GlobalCodeCheck(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:GlobalCodeCheckRH', [a:Callback])
  \}
  call s:RawRequest({}, '/codecheck', opts)
endfunction

function! s:GlobalCodeCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse(a:response.Body.QuickFixes))
endfunction


function! OmniSharp#stdio#CodeStructure(bufnr, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeStructureRH', [a:bufnr, a:Callback]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0
  \}
  call OmniSharp#stdio#Request('/v2/codestructure', opts)
endfunction

function! s:CodeStructureRH(bufnr, Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(a:bufnr, a:response.Body.Elements)
endfunction


function! OmniSharp#stdio#FindSymbol(filter, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FindSymbolRH', [a:Callback]),
  \ 'Parameters': { 'Filter': a:filter }
  \}
  call OmniSharp#stdio#Request('/findsymbols', opts)
endfunction

function! s:FindSymbolRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(OmniSharp#locations#Parse(a:response.Body.QuickFixes))
endfunction


function! OmniSharp#stdio#GetCodeActions(mode, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:GetCodeActionsRH', [a:Callback]),
  \ 'SavePosition': 1
  \}
  if a:mode ==# 'visual'
    let start = getpos("'<")
    let end = getpos("'>")
    " In visual line mode, getpos("'>")[2] is a large number (2147483647).
    " When this value is too large, use the length of the line as the column
    " position.
    if end[2] > 99999
      let end[2] = len(getline(end[1]))
    endif
    let s:codeActionParameters = {
    \ 'Selection': {
    \   'Start': {
    \     'Line': start[1],
    \     'Column': start[2]
    \   },
    \   'End': {
    \     'Line': end[1],
    \     'Column': end[2]
    \   }
    \ }
    \}
    let opts.Parameters = s:codeActionParameters
  else
    if exists('s:codeActionParameters')
      unlet s:codeActionParameters
    endif
  endif
  call OmniSharp#stdio#Request('/v2/getcodeactions', opts)
endfunction

function! s:GetCodeActionsRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(a:response.Body.CodeActions)
endfunction


function! OmniSharp#stdio#RenameTo(renameto, opts) abort
  let opts = {
  \ 'ResponseHandler': function('s:PerformChangesRH', [a:opts]),
  \ 'Parameters': {
  \   'RenameTo': a:renameto,
  \   'WantsTextChanges': 1
  \ }
  \}
  call OmniSharp#stdio#Request('/rename', opts)
endfunction


function! OmniSharp#stdio#RunCodeAction(action, ...) abort
  let opts = {
  \ 'ResponseHandler': function('s:PerformChangesRH', [a:0 ? a:1 : {}]),
  \ 'Parameters': {
  \   'Identifier': a:action.Identifier,
  \   'WantsTextChanges': 1
  \ },
  \ 'UsePreviousPosition': 1
  \}
  if exists('s:codeActionParameters')
    call extend(opts.Parameters, s:codeActionParameters, 'force')
  endif
  call OmniSharp#stdio#Request('/v2/runcodeaction', opts)
endfunction

function! s:PerformChangesRH(opts, response) abort
  if !a:response.Success | return | endif
  let changes = get(a:response.Body, 'Changes', [])
  if type(changes) != type([]) || len(changes) == 0
    echo 'No action taken'
  else
    let winview = winsaveview()
    let bufname = bufname('%')
    let bufnr = bufnr('%')
    let hidden_bak = &hidden | set hidden
    for change in changes
      call OmniSharp#locations#Navigate({
      \ 'filename': OmniSharp#util#TranslatePathForClient(change.FileName),
      \}, 1)
      call OmniSharp#buffer#Update(change)
      if bufnr('%') != bufnr
        silent write | silent edit
      endif
    endfor
    if bufnr('%') != bufnr
      call OmniSharp#locations#Navigate({
      \ 'filename': bufname
      \}, 1)
    endif
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


function! OmniSharp#stdio#Project(bufnr, Callback) abort
  if has_key(OmniSharp#GetHost(a:bufnr), 'project')
    call a:Callback()
    return
  endif
  let opts = {
  \ 'ResponseHandler': function('s:ProjectRH', [a:Callback, a:bufnr]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0
  \}
  call OmniSharp#stdio#Request('/project', opts)
endfunction

function! s:ProjectRH(Callback, bufnr, response) abort
  if !a:response.Success | return | endif
  let host = OmniSharp#GetHost(a:bufnr)
  let host.project = a:response.Body
  call a:Callback()
endfunction


let s:runningTest = 0

function! OmniSharp#stdio#RunTestsInFile(files, Callback) abort
  if s:runningTest
    echohl WarningMsg | echomsg 'A test is already running' | echohl None
    return
  endif
  let buffers = []
  for l:file in a:files
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
  call s:AwaitParallel(
  \ map(copy(buffers), {i,b -> function('OmniSharp#stdio#Project', [b])}),
  \ function('s:FindTestsInFiles', [a:Callback, buffers]))
endfunction

function! s:FindTestsInFiles(Callback, buffers, ...) abort
  call s:AwaitParallel(
  \ map(copy(a:buffers), {i,b -> function('OmniSharp#stdio#CodeStructure', [b])}),
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
    call s:AwaitParallel(Requests, a:Callback)
  else
    call s:AwaitSequence(Requests, a:Callback)
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

function! OmniSharp#stdio#RunTest(bufnr, Callback) abort
  if s:runningTest
    echohl WarningMsg | echomsg 'A test is already running' | echohl None
    return
  endif
  if !has_key(OmniSharp#GetHost(a:bufnr), 'project')
    " Initialize the test by fetching the project for the buffer - then call
    " this function again in the callback
    call OmniSharp#stdio#Project(a:bufnr,
    \ function('OmniSharp#stdio#RunTest', [a:bufnr, a:Callback]))
    return
  endif
  let s:runningTest = 1
  call OmniSharp#stdio#CodeStructure(a:bufnr,
  \ function('s:RunTest', [a:Callback]))
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


function! OmniSharp#stdio#UpdateBuffer(opts) abort
  let opts = {
  \ 'ResponseHandler': function('s:UpdateBufferRH', [a:opts])
  \}
  call OmniSharp#stdio#Request('/updatebuffer', opts)
endfunction

function! s:UpdateBufferRH(opts, response) abort
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
