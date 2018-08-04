if !(has('python') || has('python3'))
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

" Load python helper functions
call OmniSharp#py#bootstrap()

" Buffer variable constants
let s:SERVER_BUF_VAR = 'Omnisharp_buf_server'

" Setup variable defaults
let s:allUserTypes = ''
let s:allUserInterfaces = ''
let s:allUserAttributes = ''
let s:generated_snippets = {}
let s:last_completion_dictionary = {}
let s:alive_cache = []
let g:OmniSharp_py_err = {}

" Note: something about backwards compatibility
let s:initial_server_ports = copy(g:OmniSharp_sln_ports)

function! OmniSharp#GetPort(...) abort
  if exists('g:OmniSharp_port')
    return g:OmniSharp_port
  endif

  let sln_or_dir = a:0 ? a:1 : OmniSharp#FindSolutionOrDir()
  if empty(sln_or_dir)
    return 0
  endif

  " If we're already running this solution, choose the port we're running on
  if has_key(g:OmniSharp_sln_ports, sln_or_dir)
    return g:OmniSharp_sln_ports[sln_or_dir]
  endif

  " Otherwise, find a free port and use that for this solution
  let port = OmniSharp#py#eval('find_free_port()')
  if OmniSharp#CheckPyError() | return 0 | endif
  let g:OmniSharp_sln_ports[sln_or_dir] = port
  return port
endfunction

" Called from python
function! OmniSharp#GetHost(...) abort
  let bufnum = a:0 ? a:1 : bufnr('%')

  if empty(getbufvar(bufnum, 'OmniSharp_host'))
    let sln_or_dir = OmniSharp#FindSolutionOrDir(1, bufnum)
    let port = OmniSharp#GetPort(sln_or_dir)
    if port == 0
      " If user has not explicitly specified a port, try 2000
      return 'http://localhost:2000'
    endif
    let host = get(g:, 'OmniSharp_host', 'http://localhost:' . port)
    call setbufvar(bufnum, 'OmniSharp_host', host)
  endif
  return getbufvar(bufnum, 'OmniSharp_host')
endfunction

function! OmniSharp#GetCompletions(partial, ...) abort
  if !OmniSharp#IsServerRunning()
    let completions = []
  else
    let completions = OmniSharp#py#eval(printf('getCompletions(%s)', string(a:partial)))
    if OmniSharp#CheckPyError() | return [] | endif
  endif
  let s:last_completion_dictionary = {}
  for completion in completions
    let s:last_completion_dictionary[get(completion, 'word')] = completion
  endfor
  if a:0 > 0
    " If a callback has been passed in, then use it
    call a:1(completions)
  else
    " Otherwise just return the results
    return completions
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
    return OmniSharp#GetCompletions(a:base)
  endif
endfunction

function! OmniSharp#FindUsages() abort
  let qf_taglist = OmniSharp#py#eval('findUsages()')
  if OmniSharp#CheckPyError() | return | endif

  " Place the tags in the quickfix window, if possible
  if len(qf_taglist) > 0
    call s:set_quickfix(qf_taglist, 'Usages: '.expand('<cword>'))
  else
    echo 'No usages found'
  endif
endfunction

function! OmniSharp#FindImplementations() abort
  let qf_taglist = OmniSharp#py#eval('findImplementations()')
  if OmniSharp#CheckPyError() | return | endif

  if len(qf_taglist) == 0
    echo 'No implementations found'
  endif

  if len(qf_taglist) == 1
    let usage = qf_taglist[0]
    call OmniSharp#JumpToLocation(usage.filename, usage.lnum, usage.col, 0)
  endif

  if len(qf_taglist) > 1
    call s:set_quickfix(qf_taglist, 'Implementations: '.expand('<cword>'))
  endif

  return len(qf_taglist)
endfunction

function! OmniSharp#FindMembers() abort
  let qf_taglist = OmniSharp#py#eval('findMembers()')
  if OmniSharp#CheckPyError() | return | endif

  " Place the tags in the quickfix window, if possible
  " TODO: Should this use the location window instead, since it is
  " buffer-specific?
  if len(qf_taglist) > 1
    call s:set_quickfix(qf_taglist, 'Members')
  endif
endfunction

function! OmniSharp#NavigateUp() abort
  call OmniSharp#py#eval('navigateUp()')
  call OmniSharp#CheckPyError()
endfunction

" Find the solution for this file.
" Caches result
function! OmniSharp#FindSolutionOrDir(...) abort
  let interactive = a:0 ? a:1 : 1
  let bufnum = a:0 > 1 ? a:2 : bufnr('%')
  if empty(getbufvar(bufnum, s:SERVER_BUF_VAR))
    try
      let sln = s:FindSolution(interactive, bufnum)
    catch e
      return ''
    endtry
    call setbufvar(bufnum, s:SERVER_BUF_VAR, sln)
  endif
  return getbufvar(bufnum, s:SERVER_BUF_VAR)
endfunction

function! OmniSharp#NavigateDown() abort
  call OmniSharp#py#eval('navigateDown()')
  call OmniSharp#CheckPyError()
endfunction

function! OmniSharp#GotoDefinition() abort
  call OmniSharp#py#eval('gotoDefinition()')
  call OmniSharp#CheckPyError()
endfunction

function! OmniSharp#JumpToLocation(filename, line, column, noautocmds) abort
  if a:filename !=# ''
    if fnamemodify(a:filename, ':p') !=# expand('%:p')
      let command = 'edit ' . fnameescape(a:filename)
      if a:noautocmds
        let command = 'noautocmd ' . command
      endif
      try
        execute command
      catch /^Vim(edit):E37/
        call OmniSharp#util#EchoErr('No write since last change')
        return 0
      endtry
    endif
    if a:line > 0 && a:column > 0
      call cursor(a:line, a:column)
    endif
    return 1
  endif
endfunction

function! OmniSharp#FindSymbol(...) abort
  let filter = a:0 ? a:1 : ''
  if !OmniSharp#IsServerRunning()
    return
  endif
  let quickfixes = OmniSharp#py#eval(printf('findSymbols(%s)', string(filter)))
  if OmniSharp#CheckPyError() | return | endif
  if empty(quickfixes)
    echo 'No symbols found'
    return
  endif
  if g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findsymbols', quickfixes]])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#OmniSharp#findsymbols#setsymbols(quickfixes)
    call ctrlp#init(ctrlp#OmniSharp#findsymbols#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#findsymbols(quickfixes)
  else
    let title = 'Symbols'.(len(filter) ? ': '.filter : '')
    call s:set_quickfix(quickfixes, title)
  StartServerIfNotRunning() abort
  if OmniSharp#FugitiveCheck()
    return
  endif

  let sln_or_dir = OmniSharp#FindSolutionOrDir()
  if empty(sln_or_dir)
    return
  endif
  let running = 0
  let running = OmniSharp#proc#IsJobRunning(sln_or_dir)
  " If the port is hardcoded, we should check if any other vim instances have
  " started this server
  if !running && s:IsServerPortHardcoded(sln_or_dir)
    let running = OmniSharp#IsServerRunning(sln_or_dir)
  endif
  if !running
    call s:StartServer(sln_or_dir)
  endif
endfunction

function! OmniSharp#FugitiveCheck() abort
  if match( expand( '<afile>:p' ), 'fugitive:///' ) == 0
    return 1
  else
    return 0
  endif
endfunction

function! OmniSharp#StartServer(...) abort
  echo 'start server'
  let isDirectory = 0
  if a:0
    let sln_or_dir = fnamemodify(a:1, ':p')
    if filereadable(sln_or_dir)
      let file_ext = fnamemodify(sln_or_dir, ':e')
      if file_ext !=? 'sln'
        call OmniSharp#util#EchoErr("Provided file is not a solution.")
        return
      endif
    elseif !isdirectory(sln_or_dir)
      call OmniSharp#util#EchoErr("Provided path is not a sln file or a directory.")
      return
    else
      let isDirectory = 1
    end
  else
    let sln_or_dir = OmniSharp#FindSolutionOrDir()
    if empty(sln_or_dir)
      call OmniSharp#util#EchoErr("Could not find solution file or directory to start server")
      return
    endif
  endif

  call s:StartServer(sln_or_dir)

  if isDirectory
    let bufnum = bufnr('%')
    call setbufvar(bufnum, s:SERVER_BUF_VAR, sln_or_dir)
  endif

endfunction

function! s:StartServer(sln_or_dir) abort
  if OmniSharp#proc#IsJobRunning(a:sln_or_dir)
    call OmniSharp#util#EchoErr('OmniSharp is already running on ' . a:sln_or_dir)
    return
  endif

  let l:command = OmniSharp#util#get_start_cmd(a:sln_or_dir)

  if l:command ==# []
    call OmniSharp#util#EchoErr('Could not determine the command to start the OmniSharp server!')
    return
  endif

  call OmniSharp#proc#RunAsyncCommand(command, a:sln_or_dir)
endfunction

function! OmniSharp#StopAllServers() abort
  for sln_or_dir in OmniSharp#proc#ListRunningJobs()
    call OmniSharp#StopServer(1, sln_or_dir)
  endfor
endfunction

function! OmniSharp#StopServer(...) abort
  let sln_or_dir = get(b:, s:SERVER_BUF_VAR, '')
  if a:0 > 0
    let force = a:1
    if a:0 > 1
      let sln_or_dir = a:2
    endif
  else
    let force = 0
  endif

  if force || OmniSharp#proc#IsJobRunning(sln_or_dir)
    call s:BustAliveCache(sln_or_dir)
    call OmniSharp#proc#StopJob(sln_or_dir)
  endif
endfunction

function! OmniSharp#RestartServer() abort
  let sln_or_dir = OmniSharp#FindSolutionOrDir()
  if empty(sln_or_dir)
    call OmniSharp#util#EchoErr("Could not find solution file")
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

function! OmniSharp#ExpandAutoCompleteSnippet()
  if !g:OmniSharp_want_snippet
    return
  endif

  if empty(globpath(&runtimepath, 'plugin/UltiSnips.vim'))
    call OmniSharp#util#EchoErr('g:OmniSharp_want_snippet is enabled but this requires the UltiSnips plugin and it is not installed.')
    return
  endif

  let line = strpart(getline('.'), 0, col('.')-1)
  let remove_whitespace_regex = '^\s*\(.\{-}\)\s*$'

  let completion = matchstr(line, '.*\zs\s\W.\+(.*)')
  let completion = substitute(completion, remove_whitespace_regex, '\1', '')

  let should_expand_completion = len(completion) != 0

  if should_expand_completion
    let completion = split(completion, '\.')[-1]
    let completion = split(completion, 'new ')[-1]
    let completion = split(completion, '= ')[-1]

    if has_key(s:last_completion_dictionary, completion)
      let snippet = get(get(s:last_completion_dictionary, completion, ''), 'snip','')
      if !has_key(s:generated_snippets, completion)
        call UltiSnips#AddSnippetWithPriority(completion, snippet, completion, 'iw', 'cs', 1)
        let s:generated_snippets[completion] = snippet
      endif
      call UltiSnips#CursorMoved()
      call UltiSnips#ExpandSnippetOrJump()
    endif
  endif
endfunction

function! OmniSharp#OpenPythonLog() abort
  let logfile = OmniSharp#py#eval('getLogFile()')
  if OmniSharp#CheckPyError() | return | endif
  exec "edit " . logfile
endfunction

function! OmniSharp#CheckPyError(...)
  let should_print = a:0 ? a:1 : 1
  if !empty(g:OmniSharp_py_err)
    if should_print
      call OmniSharp#util#EchoErr(g:OmniSharp_py_err.code . ": " . g:OmniSharp_py_err.msg)
    endif
    " If we got a connection error when hitting the server, then the server may
    " not be running anymore and we should bust the 'alive' cache
    if g:OmniSharp_py_err.code == 'CONNECTION'
      call s:BustAliveCache()
    endif
    return 1
  endif
  return 0
endfunction

function! s:FindSolution(interactive, bufnum) abort
  let solution_files = s:find_solution_files(a:bufnum)
  if empty(solution_files)
    return ''
  endif

  if len(solution_files) == 1
    return solution_files[0]
  elseif g:OmniSharp_sln_list_index > -1 &&
  \     g:OmniSharp_sln_list_index < len(solution_files)
    return solution_files[g:OmniSharp_sln_list_index]
  else
    if g:OmniSharp_autoselect_existing_sln
      let running_slns = []
      for solutionfile in solution_files
        if has_key(g:OmniSharp_sln_ports, solutionfile)
          call add(running_slns, solutionfile)
        endif
      endfor
      if len(running_slns) == 1
        return running_slns[0]
      endif
    endif

    if !a:interactive
      throw 'Ambiguous solution file'
    endif

    let labels = ['Solution:']
    let index = 1
    for solutionfile in solution_files
      call add(labels, index . ". " . solutionfile)
      let index += 1
    endfor

    let choice = inputlist(labels)

    if choice <= 0 || choice > len(solution_files)
      throw 'No solution selected'
    endif
    return solution_files[choice - 1]
  endif
endfunction

let s:extension = has('win32') ? '.ps1' : '.sh'
let s:script_location = expand('<sfile>:p:h:h').'/installer/omnisharp-manager'.s:extension
function! OmniSharp#Install() abort
  echo 'Installing OmniSharp Roslyn...'
  call OmniSharp#StopAllServers()
  if has('win32')
    let l:location = expand('$HOME').'\.omnisharp\omnisharp-roslyn'
    call system('powershell "& ""'.s:script_location.'""" -H -l "'.l:location.'"')
  else
    call system('sh "'.s:script_location.'" -Hl "$HOME/.omnisharp/omnisharp-roslyn/"')
  endif
  echomsg 'OmniSharp installed to: ~/.omnisharp/omnisharp-roslyn/'
endfunction

function! s:find_solution_files(bufnum) abort
  "get the path for the current buffer
  let dir = expand('#' . a:bufnum . ':p:h')
  let lastfolder = ''
  let solution_files = []

  while dir !=# lastfolder
    if empty(solution_files)
      let solution_files += s:globpath(dir, '*.sln')
      let solution_files += s:globpath(dir, 'project.json')

      call filter(solution_files, 'filereadable(v:val)')
    endif

    if g:OmniSharp_prefer_global_sln
      let global_solution_files = s:globpath(dir, 'global.json')
      call filter(global_solution_files, 'filereadable(v:val)')
      if !empty(global_solution_files)
        let solution_files = [dir]
        break
      endif
    endif

    let lastfolder = dir
    let dir = fnamemodify(dir, ':h')
  endwhile

  if empty(solution_files) && g:OmniSharp_start_without_solution
    let solution_files = [getcwd()]
  endif

  return solution_files
endfunction

function! s:IsServerPortHardcoded(sln_file) abort
  if exists('g:OmniSharp_port')
    return 1
  endif
  return has_key(s:initial_server_ports, a:sln_file)
endfunction

" Remove a solution from the alive_cache
function! s:BustAliveCache(...) abort
  let sln_or_dir = a:0 ? a:1 : OmniSharp#FindSolutionOrDir(0)
  let idx = index(s:alive_cache, sln_or_dir)
  if idx != -1
    call remove(s:alive_cache, idx)
  endif
endfunction

function! s:set_quickfix(list, title)
  if !has('patch-8.0.0657')
  \ || setqflist([], ' ', {'nr': '$', 'items': a:list, 'title': a:title}) == -1
    call setqflist(a:list)
  endif
  if g:OmniSharp_open_quickfix
    botright cwindow 4
  endif
endfunction

" Manually write content to the preview window.
" Opens a preview window to a scratch buffer named '__OmniSharpScratch__'
function! s:writeToPreview(content)
  silent pedit __OmniSharpScratch__
  silent wincmd P
  setlocal modifiable noreadonly
  setlocal nobuflisted buftype=nofile bufhidden=wipe
  0,$d
  silent put =a:content
  0d_
  setlocal nomodifiable readonly
  silent wincmd p
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

let &cpo = s:save_cpo
unlet s:save_cpo

" vim: shiftwidth=2
