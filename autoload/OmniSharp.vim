if !OmniSharp#util#CheckCapabilities() | finish | endif

let s:save_cpo = &cpoptions
set cpoptions&vim

if !g:OmniSharp_server_stdio
  " Load python helper functions
  call OmniSharp#py#Bootstrap()
endif

function! OmniSharp#GetHost(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  if g:OmniSharp_server_stdio
    " Using the stdio server, b:OmniSharp_host is a dict containing the
    " `sln_or_dir` and an `initialized` flag indicating whether this buffer has
    " successfully been registered with the server:
    " { 'sln_or_dir': '/path/to/solution_or_dir', 'initialized': 1 }
    let host = getbufvar(bufnr, 'OmniSharp_host', {})
    if get(host, 'sln_or_dir', '') ==# ''
      let host.sln_or_dir = OmniSharp#FindSolutionOrDir(1, bufnr)
      let host.initialized = 0
      call setbufvar(bufnr, 'OmniSharp_host', host)
    endif
    " The returned dict includes the job, but the job is _not_ part of
    " b:OmniSharp_host. It is important to always fetch the job from
    " OmniSharp#proc#GetJob, ensuring that the job properties (job.job_id,
    " job.loaded, job.pid etc.) are always correct and up-to-date.
    return extend(copy(host), { 'job': OmniSharp#proc#GetJob(host.sln_or_dir) })
  else
    " Using the HTTP server, b:OmniSharp_host is a localhost URL
    if empty(getbufvar(bufnr, 'OmniSharp_host'))
      let sln_or_dir = OmniSharp#FindSolutionOrDir(1, bufnr)
      let port = OmniSharp#py#GetPort(sln_or_dir)
      if port == 0
        return ''
      endif
      let host = get(g:, 'OmniSharp_host', 'http://localhost:' . port)
      call setbufvar(bufnr, 'OmniSharp_host', host)
    endif
    return getbufvar(bufnr, 'OmniSharp_host')
  endif
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


function! OmniSharp#CompleteRunningSln(arglead, cmdline, cursorpos) abort
  let jobs = OmniSharp#proc#ListRunningJobs()
  return filter(jobs, {_,job -> job =~? a:arglead})
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
    if !OmniSharp#py#IsServerPortHardcoded(sln_or_dir) && !running
      return 0
    endif
  endif

  if g:OmniSharp_server_stdio
    return OmniSharp#proc#GetJob(sln_or_dir).loaded
  else
    return OmniSharp#py#CheckAlive(sln_or_dir)
  endif
endfunction

" Find the solution or directory for this file.
function! OmniSharp#FindSolutionOrDir(...) abort
  let interactive = a:0 ? a:1 : 1
  let bufnr = a:0 > 1 ? a:2 : bufnr('%')
  if empty(getbufvar(bufnr, 'OmniSharp_buf_server'))
    try
      let sln = s:FindSolution(interactive, bufnr)
      call setbufvar(bufnr, 'OmniSharp_buf_server', sln)
    catch
      return ''
    endtry
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
    let job = OmniSharp#proc#GetJob(sln_or_dir)
    if type(job) == type({}) && get(job, 'stopped')
      " The job has been manually stopped - do not start it again until
      " instructed
      return
    endif
    let running = OmniSharp#proc#IsJobRunning(sln_or_dir)
    if !g:OmniSharp_server_stdio
      " If the port is hardcoded, we should check if any other vim instances
      " have started this server
      if !running && OmniSharp#py#IsServerPortHardcoded(sln_or_dir)
        let running = OmniSharp#IsServerRunning({ 'sln_or_dir': sln_or_dir })
      endif
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

  call OmniSharp#proc#Start(command, a:sln_or_dir)
  if g:OmniSharp_server_stdio
    let b:OmniSharp_host = {
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
  let sln_or_dir = a:0 > 1 && len(a:2) > 0 ? a:2 : OmniSharp#FindSolutionOrDir()
  if force || OmniSharp#proc#IsJobRunning(sln_or_dir)
    if !g:OmniSharp_server_stdio
      call OmniSharp#py#Uncache(sln_or_dir)
    endif
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


function! s:FindSolution(interactive, bufnr) abort
  let solution_files = s:FindSolutionsFiles(a:bufnr)
  if empty(solution_files)
    " This file has no parent solution, so check for running solutions
    return s:FindRunningServerForBuffer(a:bufnr)
  endif

  if len(solution_files) == 1
    return solution_files[0]
  elseif g:OmniSharp_sln_list_index > -1 &&
  \      g:OmniSharp_sln_list_index < len(solution_files)
    return solution_files[g:OmniSharp_sln_list_index]
  else
    " Use an existing solution if one exists
    let running = s:FindRunningServerForBuffer(a:bufnr)
    if !empty(running)
      return running
    endif

    if g:OmniSharp_autoselect_existing_sln
      if !g:OmniSharp_server_stdio
        let running_slns = OmniSharp#py#FindRunningServer(solution_files)
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

" Check whether filename is in the same directory or subdirectory of a running
" server solution, or one of the solution's included projects
function! s:FindRunningServerForBuffer(bufnr) abort
  let filename = expand('#' . a:bufnr . ':p')
  let selected_sln_or_dir = ''
  let longest_dir_match = ''
  let longest_dir_length = 0
  let running_jobs = OmniSharp#proc#ListRunningJobs()
  let dir_separator = fnamemodify('.', ':p')[-1 :]
  for sln_or_dir in running_jobs
    let paths = [sln_or_dir]
    for project in get(OmniSharp#proc#GetJob(sln_or_dir), 'projects', [])
      call add(paths, OmniSharp#util#TranslatePathForClient(project.path))
    endfor
    for path in paths
      let directory = isdirectory(path) ? path : fnamemodify(path, ':h')
      if directory[len(directory) -1] != dir_separator
        let directory .= dir_separator
      endif
      if stridx(filename, directory) == 0
        if len(path) > longest_dir_length
          let longest_dir_match = path
          let selected_sln_or_dir = sln_or_dir
          let longest_dir_length = len(path)
        endif
      endif
    endfor
  endfor
  return selected_sln_or_dir
endfunction


function! OmniSharp#Status(include_dead) abort
  let jobs = map(OmniSharp#proc#ListJobs(), {_,s -> OmniSharp#proc#GetJob(s)})
  call filter(jobs, {_,j -> type(j) == type({})})
  if len(jobs) == 0
    echohl WarningMsg | echo 'No servers started' | echohl None
    return
  endif

  function! s:SortServers(j1, j2) abort
    let t1 = has_key(a:j1, 'start_time') ? reltimefloat(a:j1.start_time) : 0
    let t2 = has_key(a:j2, 'start_time') ? reltimefloat(a:j2.start_time) : 0
    return t1 == t2 ? 0 : t1 < t2 ? 1 : -1
  endfunction
  call sort(jobs, 's:SortServers')

  for job in jobs
    if OmniSharp#proc#IsJobRunning(job.sln_or_dir)
      let total = get(job, 'projects_total', 0)
      let loaded = get(job, 'projects_loaded', 0)
      let pl = total == 1 ? '' : 's'
      let pid = get(job, 'pid', '')
      if g:OmniSharp_server_stdio
        if get(job, 'loaded') || !g:OmniSharp_server_stdio
          echohl Title
            let status = printf('running (%d project%s)', total, pl)
        else
          echohl ModeMsg
          let status = printf('loading (%d of %d project%s)', loaded, total, pl)
        endif
      else
        if OmniSharp#py#CheckAlive(job.sln_or_dir)
          echohl Title
          let status = 'running'
        else
          echohl ModeMsg
          let status = 'not running'
        endif
      endif
      if has_key(job, 'start_time')
        let seconds = float2nr(reltimefloat(reltime(job.start_time)))
        if seconds < 60
          let status .= printf(' for %d seconds', seconds)
        else
          let minutes = seconds / 60
          if minutes == 1
            let status .= ' for 1 minute'
          elseif minutes < 60
            let status .= printf(' for %d minutes', minutes)
          else
            let hours = minutes / 60
            let minutes %= 60
            if hours == 1
              let status .= printf(' for an hour and %d minutes', minutes)
            elseif hours < 48
              let status .= printf(' for %d hours', hours)
            else
              let status .= printf(' for %d days', hours / 24)
            endif
          endif
        endif
      endif
    elseif a:include_dead
      echohl Comment
      let status = 'not running'
      let pid = ''
    else
      continue
    endif
    echo job.sln_or_dir
    echohl None
    if !empty(pid)
      echon "\n  pid: "
      echohl Identifier
      echon pid . "\n"
      echohl None
    endif
    echo '  ' . status
  endfor
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
  let l:location = shellescape(OmniSharp#util#ServerDir())

  if has('win32')
    let l:logfile = OmniSharp#log#GetLogDir() . '\install.log'
    let l:script = shellescape(
    \ s:plugin_root_dir . '\installer\omnisharp-manager.ps1')
    let l:version_file_location = l:location . '\OmniSharpInstall-version.txt'

    let l:command = printf(
    \ 'powershell -ExecutionPolicy Bypass -File %s %s -l %s %s',
    \ l:script, l:http, l:location, l:version)
  else
    let l:logfile = OmniSharp#log#GetLogDir() . '/install.log'
    let l:script = shellescape(
    \ s:plugin_root_dir . '/installer/omnisharp-manager.sh')
    let l:mono = g:OmniSharp_server_use_mono ? '-M' : ''
    let l:net6 = g:OmniSharp_server_use_net6 ? '-6' : ''
    let l:version_file_location = l:location . '/OmniSharpInstall-version.txt'

    let l:command = printf('/bin/sh %s %s %s %s -l %s %s',
    \ l:script, l:http, l:mono, l:net6, l:location, l:version)

    if g:OmniSharp_translate_cygwin_wsl
      let l:command .= ' -W'
    endif
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
    if !has('win32') && len(l:error_msgs) > 0
      echomsg l:error_msgs[-1]
    endif

    echohl WarningMsg
    echomsg 'The full error log can be found in the file: ' l:logfile
    echohl None
  else
    let l:version = ''
    try
      let l:command = has('win32') ? 'type ' : 'cat '
      let l:version = system(l:command . l:version_file_location)
      let l:version = OmniSharp#util#Trim(l:version) . ' '
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
