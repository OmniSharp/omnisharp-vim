if !(has('python') || has('python3'))
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

" Load python helper functions
call OmniSharp#py#bootstrap()

" Setup variable defaults
let s:allUserTypes = ''
let s:allUserInterfaces = ''
let s:allUserAttributes = ''
let s:generated_snippets = {}
let s:last_completion_dictionary = {}
let s:alive_cache = []
let g:OmniSharp_py_err = {}

" Preserve backwards compatibility with older version of
" g:OmniSharp_server_ports option
if exists('g:OmniSharp_sln_ports')
  let g:OmniSharp_server_ports = g:OmniSharp_sln_ports
endif

let s:initial_server_ports = copy(g:OmniSharp_server_ports)

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

" Called from python
function! OmniSharp#GetHost(...) abort
  let bufnum = a:0 ? a:1 : bufnr('%')

  if empty(getbufvar(bufnum, 'OmniSharp_host'))
    let sln_or_dir = OmniSharp#FindSolutionOrDir(1, bufnum)
    let port = OmniSharp#GetPort(sln_or_dir)
    if port == 0
      return ''
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

  let numImpls = len(qf_taglist)
  if numImpls == 0
    echo 'No implementations found'
  else
    if numImpls == 1
      let usage = qf_taglist[0]
      call OmniSharp#JumpToLocation(usage.filename, usage.lnum, usage.col, 0)
    else " numImpls > 1
      call s:set_quickfix(qf_taglist, 'Implementations: '.expand('<cword>'))
    endif
  endif

  return numImpls
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

" Find the solution or directory for this file.
function! OmniSharp#FindSolutionOrDir(...) abort
  let interactive = a:0 ? a:1 : 1
  let bufnum = a:0 > 1 ? a:2 : bufnr('%')
  if empty(getbufvar(bufnum, 'OmniSharp_buf_server'))
    let dir = s:FindServerRunningOnParentDirectory(bufnum)
    if !empty(dir)
      call setbufvar(bufnum, 'OmniSharp_buf_server', dir)
    else
      try
        let sln = s:FindSolution(interactive, bufnum)
        call setbufvar(bufnum, 'OmniSharp_buf_server', sln)
      catch e
        return ''
      endtry
    endif
  endif

  return getbufvar(bufnum, 'OmniSharp_buf_server')
endfunction

function! OmniSharp#NavigateDown() abort
  call OmniSharp#py#eval('navigateDown()')
  call OmniSharp#CheckPyError()
endfunction

function! OmniSharp#GotoDefinition() abort
  let loc = OmniSharp#py#eval('gotoDefinition()')
  if OmniSharp#CheckPyError() | return | endif
  if type(loc) != type({}) " Check whether a dict was returned
    echo 'Not found'
  else
    call OmniSharp#JumpToLocation(loc.filename, loc.lnum, loc.col, 0)
  endif
endfunction

function! OmniSharp#PreviewDefinition() abort
  let loc = OmniSharp#py#eval('gotoDefinition()')
  if OmniSharp#CheckPyError() | return | endif
  if type(loc) != type({}) " Check whether a dict was returned
    echo 'Not found'
  else
    call s:openLocationInPreview(loc)
    echo fnamemodify(loc.filename, ':.')
  endif
endfunction

function! OmniSharp#PreviewImplementation() abort
  let locations = OmniSharp#py#eval('findImplementations()')
  if OmniSharp#CheckPyError() | return | endif
  let numImplementations = len(locations)
  if numImplementations == 0
    echo 'No implementations found'
  else
    call s:openLocationInPreview(locations[0])
    let fname = fnamemodify(locations[0].filename, ':.')
    if numImplementations == 1
      echo fname
    else
      echo fname . ': Implementation 1 of ' . numImplementations
    endif
  endif
endfunction

function! s:openLocationInPreview(loc) abort
  let lazyredraw_bak = &lazyredraw
  let &lazyredraw = 1
  " Due to cursor jumping bug, opening preview at current file is not as
  " simple as `pedit %`:
  " http://vim.1045645.n5.nabble.com/BUG-BufReadPre-autocmd-changes-cursor-position-on-pedit-td1206965.html
  let winview = winsaveview()

  execute 'silent pedit' a:loc.filename
  wincmd P
  call cursor(a:loc.lnum, a:loc.col)
  normal! zt
  wincmd p

  " Jump cursor back to symbol.
  call winrestview(winview)
  let &lazyredraw = lazyredraw_bak
endfunction

function! OmniSharp#JumpToLocation(filename, line, column, noautocmds) abort
  if a:filename !=# ''
    if fnamemodify(a:filename, ':p') ==# expand('%:p')
      " Update the ' mark, adding this location to the jumplist. This is not
      " necessary when the location is in another buffer - :edit performs the
      " same functionality.
      normal! m'
    else
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
  endif
endfunction

" This function returns a count of the currently available code actions. It also
" uses the code actions to pre-populate the code actions for
" OmniSharp#GetCodeActions, and clears them on CursorMoved.
"
" If a callback function is passed in, the callback will also be called on
" CursorMoved, allowing this function to be used to set up a temporary "Code
" actions available" flag, e.g. in the statusline or signs column, and the
" callback function can be used to clear the flag.
function! OmniSharp#CountCodeActions(...) abort
  let actions = OmniSharp#py#eval('getCodeActions("normal")')
  if OmniSharp#CheckPyError() | return 0 | endif
  let s:actions = actions

  " v:t_func was added in vim8 - this form is backwards-compatible
  if a:0 && type(a:1) == type(function('tr'))
    let s:cb = a:1
  endif

  function! s:CleanupCodeActions() abort
    unlet s:actions
    if exists('s:cb')
      call s:cb()
      unlet s:cb
    endif
    autocmd! OmniSharp#CountCodeActions
  endfunction

  augroup OmniSharp#CountCodeActions
    autocmd!
    autocmd CursorMoved <buffer> call s:CleanupCodeActions()
    autocmd CursorMovedI <buffer> call s:CleanupCodeActions()
    autocmd BufLeave <buffer> call s:CleanupCodeActions()
  augroup END

  return len(s:actions)
endfunction

function! OmniSharp#GetCodeActions(mode) range abort
  if exists('s:actions')
    let actions = s:actions
  else
    let command = printf('getCodeActions(%s)', string(a:mode))
    let actions = OmniSharp#py#eval(command)
    if OmniSharp#CheckPyError() | return | endif
  endif
  if empty(actions)
    echo 'No code actions found'
    return
  endif
  if g:OmniSharp_selector_ui ==? 'unite'
    let context = {'empty': 0, 'auto_resize': 1}
    call unite#start([['OmniSharp/findcodeactions', a:mode, actions]], context)
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#OmniSharp#findcodeactions#setactions(a:mode, actions)
    call ctrlp#init(ctrlp#OmniSharp#findcodeactions#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#getcodeactions(a:mode, actions)
  else
    let message = []
    let i = 0
    for action in actions
      let i += 1
      call add(message, printf(' %2d. %s', i, action.Name))
    endfor
    call add(message, 'Enter an action number, or just hit Enter to cancel: ')
    let selection = str2nr(input(join(message, "\n")))
    if type(selection) == type(0) && selection > 0 && selection <= i
      let action = actions[selection - 1]
      let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
      let command = printf('runCodeAction(''%s'', ''%s'')', a:mode, command)

      let action = OmniSharp#py#eval(command)
      if OmniSharp#CheckPyError() | return | endif
      if !action
        echo 'No action taken'
      endif
    endif
  endif
endfunction

function! OmniSharp#CodeCheck() abort
  if pumvisible()
    return get(b:, 'codecheck', [])
  endif
  if bufname('%') ==# ''
    return []
  endif
  if OmniSharp#IsServerRunning()
    let codecheck = OmniSharp#py#eval('codeCheck()')
    if OmniSharp#CheckPyError() | return [] | endif
    let b:codecheck = codecheck
  endif
  return get(b:, 'codecheck', [])
endfunction

function! OmniSharp#TypeLookupWithoutDocumentation() abort
  call OmniSharp#TypeLookup(0)
endfunction

function! OmniSharp#TypeLookupWithDocumentation() abort
  call OmniSharp#TypeLookup(1)
endfunction

function! OmniSharp#TypeLookup(includeDocumentation) abort
  if g:OmniSharp_typeLookupInPreview || a:includeDocumentation
    let ret = OmniSharp#py#eval('typeLookup(True)')
    if OmniSharp#CheckPyError() | return | endif
    if len(ret.doc) > 0
      call s:writeToPreview(ret.type . "\n\n" . ret.doc)
    else
      call s:writeToPreview(ret.type)
    endif
  else
    let ret = OmniSharp#py#eval('typeLookup(False)')
    if OmniSharp#CheckPyError() | return | endif
    call OmniSharp#Echo(ret.type)
  endif
endfunction

function! OmniSharp#SignatureHelp() abort
  let result = OmniSharp#py#eval('signatureHelp()')
  if OmniSharp#CheckPyError() | return | endif
  if type(result) != type({})
    echo 'No signature help found'
    " Clear existing preview content
    let output = ''
  else
    if result.ActiveSignature == -1
      " No signature matches - display all options
      let output = join(map(result.Signatures, 'v:val.Label'), "\n")
    else
      let signature = result.Signatures[result.ActiveSignature]
      if len(signature.Parameters) == 0
        let output = signature.Label
      else
        let parameter = signature.Parameters[result.ActiveParameter]
        let output = join([parameter.Label, parameter.Documentation], "\n")
      endif
    endif
  endif
  call s:writeToPreview(output)
endfunction

function! OmniSharp#Echo(message) abort
  echo a:message[0:&columns * &cmdheight - 2]
endfunction

function! OmniSharp#Rename() abort
  let renameto = inputdialog('Rename to:', expand('<cword>'))
  if renameto !=# ''
    call OmniSharp#RenameTo(renameto)
  endif
endfunction

function! OmniSharp#RenameTo(renameto) abort
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
endfunction

function! OmniSharp#HighlightBuffer() abort
  if !OmniSharp#IsServerRunning() | return | endif

  let ret = OmniSharp#py#eval('findHighlightTypes()')
  if OmniSharp#CheckPyError() | return | endif

  function! s:ClearHighlight(groupname)
    try
      execute 'syntax clear' a:groupname
    catch | endtry
  endfunction

  function! s:ReadHighlightKeywords(spans) abort
    let l:types = []
    for span in a:spans
      let line = getline(span['line'])
      call add(l:types, line[span['start']-1 : span['end']-2])
    endfor
    return uniq(sort(l:types))
  endfunction

  let b:OmniSharp_types = s:ReadHighlightKeywords(ret.bufferTypes)
  let b:OmniSharp_interfaces = s:ReadHighlightKeywords(ret.bufferInterfaces)
  let b:OmniSharp_identifiers = s:ReadHighlightKeywords(ret.bufferIdentifiers)

  if exists('b:OmniSharp_types')
    silent call s:ClearHighlight('csUserType')
    silent call s:ClearHighlight('csUserInterface')
    silent call s:ClearHighlight('csUserIdentifier')
  endif

  if !empty(b:OmniSharp_types)
    execute 'syntax keyword csUserType' join(b:OmniSharp_types)
  endif
  if !empty(b:OmniSharp_interfaces)
    execute 'syntax keyword csUserInterface' join(b:OmniSharp_interfaces)
  endif
  if !empty(b:OmniSharp_identifiers)
    execute 'syntax keyword csUserIdentifier' join(b:OmniSharp_identifiers)
  endif

  silent call s:ClearHighlight('csNewType')
  syntax region csNewType start="@\@1<!\<new\>"hs=s+4 end="[;\n{(<\[]"me=e-1
  \ contains=csNew,csUserType,csUserIdentifier
endfunction

function! OmniSharp#UpdateBuffer() abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck()
    return
  endif
  if OmniSharp#BufferHasChanged() == 1
    call OmniSharp#py#eval('updateBuffer()')
    call OmniSharp#CheckPyError()
  endif
endfunction

function! OmniSharp#BufferHasChanged() abort
  if b:changedtick != get(b:, 'Omnisharp_UpdateChangeTick', -1)
    let b:Omnisharp_UpdateChangeTick = b:changedtick
    return 1
  endif
  return 0
endfunction

function! OmniSharp#CodeFormat() abort
  call OmniSharp#py#eval('codeFormat()')
  call OmniSharp#CheckPyError()
endfunction

function! OmniSharp#FixUsings() abort
  let qf_taglist = OmniSharp#py#eval('fix_usings()')
  if OmniSharp#CheckPyError() | return | endif

  if len(qf_taglist) > 0
    call s:set_quickfix(qf_taglist, 'Usings')
  endif
endfunction

function! OmniSharp#IsAnyServerRunning() abort
  return !empty(OmniSharp#proc#ListRunningJobs())
endfunction

function! OmniSharp#IsServerRunning(...) abort
  let sln_or_dir = a:0 ? a:1 : OmniSharp#FindSolutionOrDir(0)
  if empty(sln_or_dir)
    return 0
  endif

  " If the port is hardcoded, another vim instance may be running the server, so
  " we don't look for a running job and go straight to the network check.
  if !s:IsServerPortHardcoded(sln_or_dir) && !OmniSharp#proc#IsJobRunning(sln_or_dir)
    return 0
  endif

  let idx = index(s:alive_cache, sln_or_dir)
  if idx >= 0
    return 1
  endif

  let alive = OmniSharp#py#eval('checkAliveStatus()')
  if OmniSharp#CheckPyError() | return 0 | endif
  if alive
    " Cache the alive status so subsequent calls are faster
    call add(s:alive_cache, sln_or_dir)
  endif
  return alive
endfunction

function! OmniSharp#StartServerIfNotRunning(...) abort
  if OmniSharp#FugitiveCheck()
    return
  endif

  let sln_or_dir = a:0 ? a:1 : ''
  call OmniSharp#StartServer(sln_or_dir, 1)
endfunction

function! OmniSharp#FugitiveCheck() abort
  return &buftype ==# 'nofile' || match(expand('<afile>:p'), 'fugitive:///' ) == 0
endfunction

function! OmniSharp#StartServer(...) abort
  let sln_or_dir = a:0 && a:1 !=# '' ? fnamemodify(a:1, ':p') : ''
  let check_is_running = a:0 > 1 && a:2

  if sln_or_dir !=# ''
    if filereadable(sln_or_dir)
      let file_ext = fnamemodify(sln_or_dir, ':e')
      if file_ext !=? 'sln'
        call OmniSharp#util#EchoErr("Provided file '" . sln_or_dir . "' is not a solution.")
        return
      endif
    elseif !isdirectory(sln_or_dir)
      call OmniSharp#util#EchoErr("Provided path '" . sln_or_dir . "' is not a sln file or a directory.")
      return
    endif
  else
    let sln_or_dir = OmniSharp#FindSolutionOrDir()
    if empty(sln_or_dir)
      call OmniSharp#util#EchoErr('Could not find solution file or directory to start server')
      return
    endif
  endif

  " Optionally perform check if server is already running
  if check_is_running
    let running = OmniSharp#proc#IsJobRunning(sln_or_dir)
    " If the port is hardcoded, we should check if any other vim instances have
    " started this server
    if !running && s:IsServerPortHardcoded(sln_or_dir)
      let running = OmniSharp#IsServerRunning(sln_or_dir)
    endif

    if running | return | endif
  endif

  call s:StartServer(sln_or_dir)
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
  let sln_or_dir = OmniSharp#FindSolutionOrDir()
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
  exec 'edit ' . logfile
endfunction

function! OmniSharp#CheckPyError(...)
  let should_print = a:0 ? a:1 : 1
  if !empty(g:OmniSharp_py_err)
    if should_print
      call OmniSharp#util#EchoErr(g:OmniSharp_py_err.code . ': ' . g:OmniSharp_py_err.msg)
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

function! s:FindSolution(interactive, bufnum) abort
  let solution_files = s:find_solution_files(a:bufnum)
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
    return solution_files[choice - 1]
  endif
endfunction

function! s:FindServerRunningOnParentDirectory(bufnum) abort
  let filename = expand('#' . a:bufnum . ':p')
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

let s:extension = has('win32') ? '.ps1' : '.sh'
let s:script_location = expand('<sfile>:p:h:h').'/installer/omnisharp-manager'.s:extension
function! OmniSharp#Install(...) abort
  echo 'Installing OmniSharp Roslyn...'
  call OmniSharp#StopAllServers()

  let l:version = a:000 != [] ? ' -v '.a:000[0] : ''

  if has('win32')
    if s:check_valid_powershell_settings()
      let l:location = expand('$HOME').'\.omnisharp\omnisharp-roslyn'
      call system('powershell "& ""'.s:script_location.'""" -H -l "'.l:location
            \ .'"'.l:version)

      if v:shell_error
        echohl ErrorMsg
        echomsg 'Installation to "' . l:location . '" failed inside PowerShell.'
        echohl None
      else
        echomsg 'OmniSharp installed to: ' . l:location
      endif
    else
      echohl ErrorMsg
      echomsg 'Powershell is running at an ExecutionPolicy level that blocks OmniSharp-vim from installing the Roslyn server'
      echohl None
    endif
  else
    let l:mono = g:OmniSharp_server_use_mono ? ' -M' : ''
    let l:result =  systemlist('sh "'.s:script_location.'" -Hl "$HOME/.omnisharp/omnisharp-roslyn/"'
          \ .l:mono.l:version)

    if v:shell_error
      echohl ErrorMsg
      echomsg 'Failed to install the OmniSharp-Roslyn server'
      echomsg l:result[-1]
      echohl None
    else
      echomsg 'OmniSharp installed to: ~/.omnisharp/omnisharp-roslyn/'
    endif
  endif
endfunction

function! s:check_valid_powershell_settings()
  let l:ps_policy_level = system('powershell Get-ExecutionPolicy')
  return l:ps_policy_level !~# '^\(Restricted\|AllSigned\)'
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

function! s:IsServerPortHardcoded(sln_or_dir) abort
  if exists('g:OmniSharp_port')
    return 1
  endif
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

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
