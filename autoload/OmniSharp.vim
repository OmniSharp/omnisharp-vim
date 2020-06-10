if !OmniSharp#util#CheckCapabilities() | finish | endif

let s:save_cpo = &cpoptions
set cpoptions&vim

if !g:OmniSharp_server_stdio
  " Load python helper functions
  call OmniSharp#py#bootstrap()
  let g:OmniSharp_py_err = {}
endif

let s:alive_cache = get(s:, 'alive_cache', [])
let s:initial_server_ports = get(s:, 'initial_server_ports',
\ copy(g:OmniSharp_server_ports))

function! OmniSharp#GetPort(...) abort
  if exists('g:OmniSharp_port')
    return g:OmniSharp_port
  endif

  let sln_or_dir = a:0 ? a:1 : OmniSharp#FindSolutionOrDir()
  if empty(sln_or_dir)
    return 0
  endif

  " If we're already running this solution, choose the port we're running on
  if has_key(g:OmniSharp_server_ports, sln_or_dir)
    return g:OmniSharp_server_ports[sln_or_dir]
  endif

  " Otherwise, find a free port and use that for this solution
  let port = OmniSharp#py#eval('find_free_port()')
  if OmniSharp#CheckPyError() | return 0 | endif
  let g:OmniSharp_server_ports[sln_or_dir] = port
  return port
endfunction


function! OmniSharp#GetHost(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')

  if empty(getbufvar(bufnr, 'OmniSharp_host'))
    let sln_or_dir = OmniSharp#FindSolutionOrDir(1, bufnr)
    if g:OmniSharp_server_stdio
      let host = {
      \ 'job': OmniSharp#proc#GetJob(sln_or_dir),
      \ 'sln_or_dir': sln_or_dir
      \}
    else
      let port = OmniSharp#GetPort(sln_or_dir)
      if port == 0
        return ''
      endif
      let host = get(g:, 'OmniSharp_host', 'http://localhost:' . port)
    endif
    call setbufvar(bufnr, 'OmniSharp_host', host)
  endif
  if g:OmniSharp_server_stdio
    let host = getbufvar(bufnr, 'OmniSharp_host')
    if !OmniSharp#proc#IsJobRunning(host.job)
      let host.job = OmniSharp#proc#GetJob(host.sln_or_dir)
    endif
  endif
  return getbufvar(bufnr, 'OmniSharp_host')
endfunction


function! OmniSharp#Complete(findstart, base) abort
  if a:findstart
    "locate the start of the word
    let line = getline('.')
    let start = col('.') - 1
    while start > 0 && line[start - 1] =~# '\v[a-zA-z0-9_]'
      let start -= 1
    endwhile

    return start
  else
    return OmniSharp#actions#complete#Get(a:base)
  endif
endfunction


function! OmniSharp#FindUsages(...) abort
  call s:WarnObsolete('OmniSharp#actions#usages#Find()')
  call OmniSharp#actions#usages#Find(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#FindImplementations(...) abort
  call s:WarnObsolete('OmniSharp#actions#implementations#Find()')
  call OmniSharp#actions#implementations#Find(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#FindMembers(...) abort
  call s:WarnObsolete('OmniSharp#actions#members#Find()')
  call OmniSharp#actions#members#Find(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#NavigateDown() abort
  call s:WarnObsolete('OmniSharp#actions#navigate#Down()')
  call OmniSharp#actions#navigate#Down()
endfunction

function! OmniSharp#NavigateUp() abort
  call s:WarnObsolete('OmniSharp#actions#navigate#Up()')
  call OmniSharp#actions#navigate#Up()
endfunction

function! OmniSharp#GotoDefinition(...) abort
  call s:WarnObsolete('OmniSharp#actions#definition#Find()')
  call OmniSharp#actions#definition#Find(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#PreviewDefinition(...) abort
  call s:WarnObsolete('OmniSharp#actions#definition#Preview()')
  call OmniSharp#actions#definition#Preview(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#PreviewImplementation() abort
  call s:WarnObsolete('OmniSharp#actions#implementations#Preview()')
  call OmniSharp#actions#implementations#Preview()
endfunction


function! OmniSharp#FindSymbol(...) abort
  let filter = a:0 ? a:1 : ''
  if !OmniSharp#IsServerRunning() | return | endif
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBFindSymbol', [filter])
    call OmniSharp#stdio#FindSymbol(filter, Callback)
  else
    let locs = OmniSharp#py#eval(printf('findSymbols(%s)', string(filter)))
    if OmniSharp#CheckPyError() | return | endif
    return s:CBFindSymbol(filter, locs)
  endif
endfunction

function! s:CBFindSymbol(filter, locations) abort
  if empty(a:locations)
    echo 'No symbols found'
    return
  endif
  if g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findsymbols', a:locations]])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#OmniSharp#findsymbols#setsymbols(a:locations)
    call ctrlp#init(ctrlp#OmniSharp#findsymbols#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#FindSymbols(a:locations)
  else
    let title = 'Symbols' . (len(a:filter) ? ': ' . a:filter : '')
    call OmniSharp#locations#SetQuickfix(a:locations, title)
  endif
endfunction


" This function returns a count of the currently available code actions. It also
" uses the code actions to pre-populate the code actions for
" OmniSharp#GetCodeActions, and clears them on CursorMoved.
"
" If a single callback function is passed in, the callback will be called on
" CursorMoved, allowing this function to be used to set up a temporary "Code
" actions available" flag, e.g. in the statusline or signs column, and the
" callback function can be used to clear the flag.
"
" If a dict is passed in, the dict may contain one or both of 'CallbackCleanup'
" and 'CallbackCount' Funcrefs. 'CallbackCleanup' is the single callback
" function mentioned above. 'CallbackCount' is called after a response with the
" number of actions available.
"
" call OmniSharp#CountCodeActions({-> execute('sign unplace 99')})
" call OmniSharp#CountCodeActions({
" \ 'CallbackCleanup': {-> execute('sign unplace 99')},
" \ 'CallbackCount': function('PlaceSign')
" \}
function! OmniSharp#CountCodeActions(...) abort
  if a:0 && type(a:1) == type(function('tr'))
    let opts = { 'CallbackCleanup': a:1 }
  elseif a:0 && type(a:1) == type({})
    let opts = a:1
  endif

  if g:OmniSharp_server_stdio
    let Callback = function('s:CBCountCodeActions', [opts])
    call OmniSharp#stdio#GetCodeActions('normal', Callback)
  else
    let actions = OmniSharp#py#eval('getCodeActions("normal")')
    if OmniSharp#CheckPyError() | return | endif
    call s:CBCountCodeActions(opts, actions)
  endif
endfunction

function! s:CBCountCodeActions(opts, actions) abort
  let s:actions = a:actions

  if has_key(a:opts, 'CallbackCount')
    call a:opts.CallbackCount(len(s:actions))
  endif
  let s:Cleanup = function('s:CleanupCodeActions', [a:opts])

  augroup OmniSharp_CountCodeActions
    autocmd!
    autocmd CursorMoved <buffer> call s:Cleanup()
    autocmd CursorMovedI <buffer> call s:Cleanup()
    autocmd BufLeave <buffer> call s:Cleanup()
  augroup END

  return len(s:actions)
endfunction

function! s:CleanupCodeActions(opts) abort
  unlet s:actions
  unlet s:Cleanup
  if has_key(a:opts, 'CallbackCleanup')
    call a:opts.CallbackCleanup()
  endif
  autocmd! OmniSharp_CountCodeActions
endfunction

function! OmniSharp#GetCodeActions(mode) range abort
  if exists('s:actions')
    call s:CBGetCodeActions(a:mode, s:actions)
  elseif g:OmniSharp_server_stdio
    let Callback = function('s:CBGetCodeActions', [a:mode])
    call OmniSharp#stdio#GetCodeActions(a:mode, Callback)
  else
    let command = printf('getCodeActions(%s)', string(a:mode))
    let actions = OmniSharp#py#eval(command)
    if OmniSharp#CheckPyError() | return | endif
    call s:CBGetCodeActions(a:mode, actions)
  endif
endfunction

function! s:CBGetCodeActions(mode, actions) abort
  if empty(a:actions)
    echo 'No code actions found'
    return
  endif
  if g:OmniSharp_selector_ui ==? 'unite'
    let context = {'empty': 0, 'auto_resize': 1}
    call unite#start([['OmniSharp/findcodeactions', a:mode, a:actions]], context)
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#OmniSharp#findcodeactions#setactions(a:mode, a:actions)
    call ctrlp#init(ctrlp#OmniSharp#findcodeactions#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#GetCodeActions(a:mode, a:actions)
  else
    let message = []
    let i = 0
    for action in a:actions
      let i += 1
      call add(message, printf(' %2d. %s', i, action.Name))
    endfor
    call add(message, 'Enter an action number, or just hit Enter to cancel: ')
    let selection = str2nr(input(join(message, "\n")))
    if type(selection) == type(0) && selection > 0 && selection <= i
      let action = a:actions[selection - 1]
      if g:OmniSharp_server_stdio
        call OmniSharp#stdio#RunCodeAction(action)
      else
        let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
        let command = printf('runCodeAction(''%s'', ''%s'')', a:mode, command)
        let action = OmniSharp#py#eval(command)
        if OmniSharp#CheckPyError() | return | endif
        if !action
          echo 'No action taken'
        endif
      endif
    endif
  endif
endfunction


" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the results
function! OmniSharp#CodeCheck(...) abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return [] | endif
  if pumvisible() || !OmniSharp#IsServerRunning()
    return get(b:, 'codecheck', [])
  endif
  let opts = a:0 ? { 'Callback': a:1 } : {}
  if g:OmniSharp_server_stdio
    call OmniSharp#stdio#CodeCheck({}, function('s:CBCodeCheck', [opts]))
  else
    let codecheck = OmniSharp#py#eval('codeCheck()')
    if OmniSharp#CheckPyError() | return | endif
    return s:CBCodeCheck(opts, codecheck)
  endif
endfunction

function! s:CBCodeCheck(opts, codecheck) abort
  let b:codecheck = a:codecheck
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(a:codecheck)
  endif
  return b:codecheck
endfunction

function! OmniSharp#GlobalCodeCheck() abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return [] | endif
  " Place the results in the quickfix window, if possible
  if g:OmniSharp_server_stdio
    call OmniSharp#stdio#GlobalCodeCheck(function('s:CBGlobalCodeCheck'))
  else
    let quickfixes = OmniSharp#py#eval('globalCodeCheck()')
    if OmniSharp#CheckPyError() | return | endif
    return s:CBGlobalCodeCheck(quickfixes)
  endif
endfunction

function! s:CBGlobalCodeCheck(quickfixes) abort
  if len(a:quickfixes) > 0
    call OmniSharp#locations#SetQuickfix(a:quickfixes, 'Code Check Messages')
  else
    echo 'No Code Check messages'
  endif
endfunction


function! OmniSharp#RunTestsInFile(...) abort
  if !s:GuardStdio() | return | endif
  if g:OmniSharp_translate_cygwin_wsl
    echohl WarningMsg
    echomsg 'Tests do not work in WSL unfortunately'
    echohl None
    return
  endif
  if a:0 == 0
    let files = [expand('%:p')]
  elseif type(a:1) == type([])
    let files = a:1
  elseif type(a:1) == type('')
    let files = a:000
  endif
  let files = map(copy(files), {i,f -> fnamemodify(f, ':p')})
  call OmniSharp#stdio#RunTestsInFile(files, function('s:CBRunTestsInFile'))
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

function! OmniSharp#RunTest() abort
  if !s:GuardStdio() | return | endif
  if g:OmniSharp_translate_cygwin_wsl
    echohl WarningMsg
    echomsg 'Tests do not work in WSL unfortunately'
    echohl None
    return
  endif
  call OmniSharp#stdio#RunTest(bufnr('%'), function('s:CBRunTest'))
endfunction

function! s:CBRunTest(summary) abort
  if a:summary.pass
    if len(a:summary.locations) == 0
      echomsg 'No tests were run'
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


function! OmniSharp#TypeLookupWithoutDocumentation(...) abort
  call s:WarnObsolete('OmniSharp#actions#documentation#TypeLookup()')
  call OmniSharp#actions#documentation#TypeLookup(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#TypeLookupWithDocumentation(...) abort
  call s:WarnObsolete('OmniSharp#actions#documentation#Documentation()')
  call OmniSharp#actions#documentation#Documentation(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#SignatureHelp() abort
  call s:WarnObsolete('OmniSharp#actions#signature#SignatureHelp()')
  call OmniSharp#actions#signature#SignatureHelp()
endfunction


function! OmniSharp#Rename() abort
  let renameto = inputdialog('Rename to: ', expand('<cword>'))
  if renameto !=# ''
    call OmniSharp#RenameTo(renameto)
  endif
endfunction

function! OmniSharp#RenameTo(renameto, ...) abort
  let opts = a:0 ? { 'Callback': a:1 } : {}
  if g:OmniSharp_server_stdio
    call OmniSharp#stdio#RenameTo(a:renameto, opts)
  else
    let command = printf('renameTo(%s)', string(a:renameto))
    let changes = OmniSharp#py#eval(command)
    if OmniSharp#CheckPyError() | return | endif

    let save_lazyredraw = &lazyredraw
    let save_eventignore = &eventignore
    let buf = bufnr('%')
    let curpos = getpos('.')
    let view = winsaveview()
    try
      set lazyredraw eventignore=all
      for change in changes
        execute 'silent hide edit' fnameescape(change.FileName)
        let modified = &modified
        let content = split(change.Buffer, '\r\?\n')
        silent % delete _
        silent 1put =content
        silent 1 delete _
        if !modified
          silent update
        endif
      endfor
    finally
      if bufnr('%') != buf
        exec 'buffer ' . buf
      endif
      call setpos('.', curpos)
      call winrestview(view)
      silent update
      let &eventignore = save_eventignore
      silent edit  " reload to apply syntax
      let &lazyredraw = save_lazyredraw
    endtry
    if has_key(opts, 'Callback')
      call opts.Callback()
    endif
  endif
endfunction


function! OmniSharp#HighlightBuffer() abort
  call s:WarnObsolete('OmniSharp#actions#highlight#Buffer()')
  call OmniSharp#actions#highlight#Buffer()
endfunction

function OmniSharp#HighlightEchoKind() abort
  call s:WarnObsolete('OmniSharp#actions#highlight#Echo()')
  call OmniSharp#actions#highlight#Echo()
endfunction


" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously)
function! OmniSharp#UpdateBuffer(...) abort
  let opts = a:0 ? { 'Callback': a:1 } : {}
  if !OmniSharp#IsServerRunning() | return | endif
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return | endif
  if OmniSharp#BufferHasChanged() == 1
    if g:OmniSharp_server_stdio
      call OmniSharp#stdio#UpdateBuffer(opts)
    else
      call OmniSharp#py#eval('updateBuffer()')
      call OmniSharp#CheckPyError()
      if has_key(opts, 'Callback')
        call opts.Callback()
      endif
    endif
  endif
endfunction

function! OmniSharp#BufferHasChanged() abort
  if b:changedtick != get(b:, 'OmniSharp_UpdateChangeTick', -1)
    let b:OmniSharp_UpdateChangeTick = b:changedtick
    return 1
  endif
  return 0
endfunction


function! OmniSharp#CodeFormat(...) abort
  call s:WarnObsolete('OmniSharp#actions#format#Format()')
  call OmniSharp#actions#format#Format(a:0 ? a:1 : 0)
endfunction

function! OmniSharp#FixUsings(...) abort
  call s:WarnObsolete('OmniSharp#actions#usings#Fix()')
  call OmniSharp#actions#usings#Fix(a:0 ? a:1 : 0)
endfunction


function! OmniSharp#IsAnyServerRunning() abort
  return !empty(OmniSharp#proc#ListRunningJobs())
endfunction

function! OmniSharp#IsServerRunning(...) abort
  let opts = a:0 ? a:1 : {}
  if has_key(opts, 'sln_or_dir')
    let sln_or_dir = opts.sln_or_dir
  else
    let bufnr = get(opts, 'bufnum', bufnr('%'))
    let sln_or_dir = OmniSharp#FindSolutionOrDir(1, bufnr)
  endif
  if empty(sln_or_dir)
    return 0
  endif

  let running = OmniSharp#proc#IsJobRunning(sln_or_dir)

  if g:OmniSharp_server_stdio
    if !running
      return 0
    endif
  else
    " If the HTTP port is hardcoded, another vim instance may be running the
    " server, so we don't look for a running job and go straight to the network
    " check. Note that this only applies to HTTP servers - Stdio servers must be
    " started by _this_ vim session.
    if !s:IsServerPortHardcoded(sln_or_dir) && !running
      return 0
    endif
  endif

  if index(s:alive_cache, sln_or_dir) >= 0 | return 1 | endif

  if g:OmniSharp_server_stdio
    let alive = OmniSharp#proc#GetJob(sln_or_dir).loaded
  else
    let alive = OmniSharp#py#eval('checkAliveStatus()')
    if OmniSharp#CheckPyError() | return 0 | endif
  endif
  if alive
    " Cache the alive status so subsequent calls are faster
    call add(s:alive_cache, sln_or_dir)
  endif
  return alive
endfunction

" Find the solution or directory for this file.
function! OmniSharp#FindSolutionOrDir(...) abort
  let interactive = a:0 ? a:1 : 1
  let bufnr = a:0 > 1 ? a:2 : bufnr('%')
  if empty(getbufvar(bufnr, 'OmniSharp_buf_server'))
    let dir = s:FindServerRunningOnParentDirectory(bufnr)
    if !empty(dir)
      call setbufvar(bufnr, 'OmniSharp_buf_server', dir)
    else
      try
        let sln = s:FindSolution(interactive, bufnr)
        call setbufvar(bufnr, 'OmniSharp_buf_server', sln)
      catch
        return ''
      endtry
    endif
  endif

  return getbufvar(bufnr, 'OmniSharp_buf_server')
endfunction

function! OmniSharp#StartServerIfNotRunning(...) abort
  if OmniSharp#FugitiveCheck() | return | endif
  " Bail early in this check if the file is a metadata file
  if type(get(b:, 'OmniSharp_metadata_filename')) == type('') | return | endif
  let sln_or_dir = a:0 ? a:1 : ''
  call OmniSharp#StartServer(sln_or_dir, 1)
endfunction

function! OmniSharp#FugitiveCheck() abort
  return &buftype ==# 'nofile'
  \ || match(expand('%:p'), '\vfugitive:(///|\\\\)' ) == 0
endfunction

function! OmniSharp#StartServer(...) abort
  let sln_or_dir = a:0 && a:1 !=# '' ? fnamemodify(a:1, ':p') : ''
  let check_is_running = a:0 > 1 && a:2

  if sln_or_dir !=# ''
    if filereadable(sln_or_dir)
      let file_ext = fnamemodify(sln_or_dir, ':e')
      if file_ext !=? 'sln'
        call OmniSharp#util#EchoErr(
        \ printf("'%s' is not a solution file", sln_or_dir))
        return
      endif
    elseif !isdirectory(sln_or_dir)
      call OmniSharp#util#EchoErr(
      \ printf("'%s' is not a solution file or directory", sln_or_dir))
      return
    endif
  else
    let sln_or_dir = OmniSharp#FindSolutionOrDir()
    if empty(sln_or_dir)
      if expand('%:e') ==? 'csx' || expand('%:e') ==? 'cake'
        " .csx and .cake files do not require solutions or projects
        let sln_or_dir = expand('%:p:h')
      else
        call OmniSharp#util#EchoErr(
        \ 'Could not find a solution or project to start server with')
        return
      endif
    endif
  endif

  " Optionally perform check if server is already running
  if check_is_running
    let running = OmniSharp#proc#IsJobRunning(sln_or_dir)
    " If the port is hardcoded, we should check if any other vim instances have
    " started this server
    if !running && s:IsServerPortHardcoded(sln_or_dir)
      let running = OmniSharp#IsServerRunning({ 'sln_or_dir': sln_or_dir })
    endif

    if running | return | endif
  endif

  call s:StartServer(sln_or_dir)
endfunction

function! s:StartServer(sln_or_dir) abort
  if OmniSharp#proc#IsJobRunning(a:sln_or_dir)
    call OmniSharp#util#EchoErr(
    \ printf("OmniSharp is already running '%s'", a:sln_or_dir))
    return
  endif

  let l:command = OmniSharp#util#GetStartCmd(a:sln_or_dir)

  if l:command ==# []
    call OmniSharp#util#EchoErr(
    \ 'Failed to build command to start the OmniSharp server')
    return
  endif

  let job = OmniSharp#proc#Start(command, a:sln_or_dir)
  if g:OmniSharp_server_stdio
    let b:OmniSharp_host = {
    \ 'job': job,
    \ 'sln_or_dir': a:sln_or_dir
    \}
  endif
endfunction

function! OmniSharp#StopAllServers() abort
  for sln_or_dir in OmniSharp#proc#ListRunningJobs()
    call OmniSharp#StopServer(1, sln_or_dir)
  endfor
endfunction

function! OmniSharp#StopServer(...) abort
  let force = a:0 ? a:1 : 0
  let sln_or_dir = a:0 > 1 ? a:2 : OmniSharp#FindSolutionOrDir()

  if force || OmniSharp#proc#IsJobRunning(sln_or_dir)
    call s:BustAliveCache(sln_or_dir)
    call OmniSharp#proc#StopJob(sln_or_dir)
  endif
endfunction

function! OmniSharp#RestartServer() abort
  let sln_or_dir = OmniSharp#FindSolutionOrDir()
  if empty(sln_or_dir)
    call OmniSharp#util#EchoErr('Could not find solution file or directory')
    return
  endif
  call OmniSharp#StopServer(1, sln_or_dir)
  sleep 500m
  call s:StartServer(sln_or_dir)
endfunction

function! OmniSharp#RestartAllServers() abort
  let running_jobs = OmniSharp#proc#ListRunningJobs()
  for sln_or_dir in running_jobs
    call OmniSharp#StopServer(1, sln_or_dir)
  endfor
  sleep 500m
  for sln_or_dir in running_jobs
    call s:StartServer(sln_or_dir)
  endfor
endfunction


function! OmniSharp#AppendCtrlPExtensions() abort
  " Don't override settings made elsewhere
  if !exists('g:ctrlp_extensions')
    let g:ctrlp_extensions = []
  endif
  if !exists('g:OmniSharp_ctrlp_extensions_added')
    let g:OmniSharp_ctrlp_extensions_added = 1
    let g:ctrlp_extensions += ['findsymbols', 'findcodeactions']
  endif
endfunction


function! OmniSharp#OpenLog(...) abort
  if g:OmniSharp_server_stdio
    let logfile = OmniSharp#stdio#GetLogFile()
  else
    let logfile = OmniSharp#py#eval('getLogFile()')
    if OmniSharp#CheckPyError() | return | endif
  endif
  let cmd = (a:0 && len(a:1)) ? a:1 : 'edit'
  exec cmd logfile
endfunction


function! OmniSharp#CheckPyError(...)
  let should_print = a:0 ? a:1 : 1
  if !empty(g:OmniSharp_py_err)
    if should_print
      call OmniSharp#util#EchoErr(
      \ printf('%s: %s', g:OmniSharp_py_err.code, g:OmniSharp_py_err.msg))
    endif
    " If we got a connection error when hitting the server, then the server may
    " not be running anymore and we should bust the 'alive' cache
    if g:OmniSharp_py_err.code ==? 'CONNECTION'
      call s:BustAliveCache()
    endif
    return 1
  endif
  return 0
endfunction


function! s:FindSolution(interactive, bufnr) abort
  let solution_files = s:FindSolutionsFiles(a:bufnr)
  if empty(solution_files)
    return ''
  endif

  if len(solution_files) == 1
    return solution_files[0]
  elseif g:OmniSharp_sln_list_index > -1 &&
  \      g:OmniSharp_sln_list_index < len(solution_files)
    return solution_files[g:OmniSharp_sln_list_index]
  else
    if g:OmniSharp_autoselect_existing_sln
      if len(g:OmniSharp_server_ports)
        " g:OmniSharp_server_ports has been set, auto-select one of the
        " specified servers
        let running_slns = []
        for solutionfile in solution_files
          if has_key(g:OmniSharp_server_ports, solutionfile)
            call add(running_slns, solutionfile)
          endif
        endfor
        if len(running_slns) == 1
          return running_slns[0]
        endif
      endif
      if exists('s:selected_sln')
        " Return the previously selected solution
        return s:selected_sln
      endif
    endif

    if !a:interactive
      throw 'Ambiguous solution file'
    endif

    let labels = ['Solution:']
    let index = 1
    for solutionfile in solution_files
      call add(labels, index . '. ' . solutionfile)
      let index += 1
    endfor

    let choice = inputlist(labels)

    if choice <= 0 || choice > len(solution_files)
      throw 'No solution selected'
    endif
    let s:selected_sln = solution_files[choice - 1]
    return s:selected_sln
  endif
endfunction

function! s:FindServerRunningOnParentDirectory(bufnr) abort
  let filename = expand('#' . a:bufnr . ':p')
  let longest_dir_match = ''
  let longest_dir_length = 0
  let running_jobs = OmniSharp#proc#ListRunningJobs()
  for sln_or_dir in running_jobs
    if isdirectory(sln_or_dir) && s:DirectoryContainsFile(sln_or_dir, filename)
      let dir_length = len(sln_or_dir)
      if dir_length > longest_dir_length
        let longest_dir_match = sln_or_dir
        let longest_dir_length = dir_length
      endif
    endif
  endfor

  return longest_dir_match
endfunction

function! s:DirectoryContainsFile(directory, file) abort
  let idx = stridx(a:file, a:directory)
  return (idx == 0)
endfunction


let s:plugin_root_dir = expand('<sfile>:p:h:h')

function! OmniSharp#Install(...) abort
  if exists('g:OmniSharp_server_path')
    echohl WarningMsg
    echomsg 'Installation not attempted, g:OmniSharp_server_path defined.'
    echohl None
    return
  endif

  echo 'Installing OmniSharp Roslyn, please wait...'

  call OmniSharp#StopAllServers()

  let l:http = g:OmniSharp_server_stdio ? '' : '-H'
  let l:version = a:0 > 0 ? '-v ' . shellescape(a:1) : ''
  let l:location = shellescape(g:OmniSharp_server_install)

  if has('win32')
    let l:logfile = s:plugin_root_dir . '\log\install.log'
    let l:script = shellescape(
    \ s:plugin_root_dir . '\installer\omnisharp-manager.ps1')
    let l:version_file_location = l:location . '\OmniSharpInstall-version.txt'

    let l:command = printf(
    \ 'powershell -ExecutionPolicy Bypass -File %s %s -l %s %s',
    \ l:script, l:http, l:location, l:version)
  else
    let l:logfile = s:plugin_root_dir . '/log/install.log'
    let l:script = shellescape(
    \ s:plugin_root_dir . '/installer/omnisharp-manager.sh')
    let l:mono = g:OmniSharp_server_use_mono ? '-M' : ''
    let l:version_file_location = l:location . '/OmniSharpInstall-version.txt'

    let l:command = printf('/bin/sh %s %s %s -l %s %s',
    \ l:script, l:http, l:mono, l:location, l:version)
  endif

  " Begin server installation
  let l:error_msgs = systemlist(l:command)

  if v:shell_error
    " Log executed command and full error log
    call writefile(['> ' . l:command, repeat('=', 80)], l:logfile)
    call writefile(l:error_msgs, l:logfile, 'a')

    echohl ErrorMsg
    echomsg 'Failed to install the OmniSharp-Roslyn server'

    " Display extra error information for Unix users
    if !has('win32')
      echomsg l:error_msgs[-1]
    endif

    echohl WarningMsg
    echomsg 'The full error log can be found in the file: ' l:logfile
    echohl None
  else
    let l:version = ''
    try
      let l:command = has('win32') ? 'type ' : 'cat '
      let l:version = trim(system(l:command . l:version_file_location)) . ' '
    catch | endtry
    echohl Title
    echomsg printf('OmniSharp-Roslyn %sinstalled to %s', l:version, l:location)
    echohl None
  endif
endfunction


function! s:FindSolutionsFiles(bufnr) abort
  "get the path for the current buffer
  let dir = expand('#' . a:bufnr . ':p:h')
  let lastfolder = ''
  let solution_files = []

  while dir !=# lastfolder
    let solution_files += s:globpath(dir, '*.sln')
    let solution_files += s:globpath(dir, 'project.json')

    call filter(solution_files, 'filereadable(v:val)')

    if g:OmniSharp_prefer_global_sln
      let global_solution_files = s:globpath(dir, 'global.json')
      call filter(global_solution_files, 'filereadable(v:val)')
      if !empty(global_solution_files)
        let solution_files = [dir]
        break
      endif
    endif

    if !empty(solution_files)
      return solution_files
    endif

    let lastfolder = dir
    let dir = fnamemodify(dir, ':h')
  endwhile

  if empty(solution_files)
    let dir = expand('#' . a:bufnr . ':p:h')
    let lastfolder = ''
    let solution_files = []

    while dir !=# lastfolder
      let solution_files += s:globpath(dir, '*.csproj')

      call uniq(map(solution_files, 'fnamemodify(v:val, ":h")'))

      if !empty(solution_files)
        return solution_files
      endif

      let lastfolder = dir
      let dir = fnamemodify(dir, ':h')
    endwhile
  endif

  if empty(solution_files) && g:OmniSharp_start_without_solution
    let solution_files = [getcwd()]
  endif

  return solution_files
endfunction

function! s:GuardStdio() abort
  if !g:OmniSharp_server_stdio
    echohl WarningMsg | echomsg 'stdio only, sorry' | echohl None
    return 0
  endif
  return 1
endfunction

function! s:IsServerPortHardcoded(sln_or_dir) abort
  if g:OmniSharp_server_stdio | return 0 | endif
  if exists('g:OmniSharp_port') | return 1 | endif
  return has_key(s:initial_server_ports, a:sln_or_dir)
endfunction

" Remove a server from the alive_cache
function! s:BustAliveCache(...) abort
  let sln_or_dir = a:0 ? a:1 : OmniSharp#FindSolutionOrDir(0)
  let idx = index(s:alive_cache, sln_or_dir)
  if idx != -1
    call remove(s:alive_cache, idx)
  endif
endfunction

function! s:WarnObsolete(newName) abort
  echohl WarningMsg
  echomsg printf('This function is obsolete; use %s instead', a:newName)
  echohl None
endfunction

if has('patch-7.4.279')
  function! s:globpath(path, file) abort
    return globpath(a:path, a:file, 1, 1)
  endfunction
else
  function! s:globpath(path, file) abort
    return split(globpath(a:path, a:file, 1), "\n")
  endfunction
endif

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
