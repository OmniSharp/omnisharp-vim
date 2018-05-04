if !has('python')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim
"
"Load python/omnisharp/OmniSharp.py
let s:py_path = OmniSharp#util#path_join(['python', 'omnisharp'])
exec "python sys.path.append(r'" . s:py_path . "')"
exec 'pyfile ' . fnameescape(OmniSharp#util#path_join(['python', 'omnisharp', 'OmniSharp.py']))

let s:server_files = '*.sln'
let s:allUserTypes = ''
let s:allUserInterfaces = ''
let s:generated_snippets = {}
let s:last_completion_dictionary = {}
let g:serverSeenRunning = 0

let s:is_vimproc = 0
silent! let s:is_vimproc = vimproc#version()

function! OmniSharp#GetCompletions(partial, ...) abort
  let completions = pyeval(printf('getCompletions(%s)', string(a:partial)))
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
  let qf_taglist = pyeval('findUsages()')

  " Place the tags in the quickfix window, if possible
  if len(qf_taglist) > 0
    call setqflist(qf_taglist)
    botright cwindow 4
  else
    echo 'No usages found'
  endif
endfunction

function! OmniSharp#FindImplementations() abort
  let qf_taglist = pyeval('findImplementations()')

  if len(qf_taglist) == 0
    echo 'No implementations found'
  endif

  if len(qf_taglist) == 1
    let usage = qf_taglist[0]
    call OmniSharp#JumpToLocation(usage.filename, usage.lnum, usage.col)
  endif

  if len(qf_taglist) > 1
    call setqflist(qf_taglist)
    botright cwindow 4
  endif
endfunction

function! OmniSharp#FindMembers() abort
  let qf_taglist = pyeval('findMembers()')

  " Place the tags in the quickfix window, if possible
  if len(qf_taglist) > 1
    call setqflist(qf_taglist)
    botright cwindow 4
  endif
endfunction

function! OmniSharp#NavigateUp() abort
  if g:OmniSharp_server_type ==# 'roslyn'
    let qf_tag = pyeval('navigateUp()')
    call cursor(qf_tag.Line, qf_tag.Column)
  else
    let qf_taglist = pyeval('findMembers()')
    let column = col('.')
    let line = line('.')
    let l = len(qf_taglist) - 1

    if l >= 0
      while l >= 0
        let qf_line = qf_taglist[l].lnum
        let qf_col = qf_taglist[l].col
        if qf_line < line || (qf_line == line && qf_col < column)
          call cursor(qf_taglist[l].lnum, qf_taglist[l].col)
          break
        endif
        let l -= 1
      endwhile
    endif
  endif
endfunction

function! OmniSharp#NavigateDown() abort
  if g:OmniSharp_server_type ==# 'roslyn'
    let qf_tag = pyeval('navigateDown()')
    call cursor(qf_tag.Line, qf_tag.Column)
  else
    let qf_taglist = pyeval('findMembers()')
    let column = col('.')
    let line = line('.')
    for l in range(0, len(qf_taglist) - 1)
      let qf_line = qf_taglist[l].lnum
      let qf_col = qf_taglist[l].col
      if qf_line > line || (qf_line == line && qf_col > column)
        call cursor(qf_taglist[l].lnum, qf_taglist[l].col)
        break
      endif
      let l += 1
    endfor
  endif
endfunction

function! OmniSharp#GotoDefinition() abort
  python gotoDefinition()
endfunction

function! OmniSharp#JumpToLocation(filename, line, column) abort
  if a:filename !=# ''
    if fnamemodify(a:filename, ':p') !=# expand('%:p')
      try
        execute 'edit ' . fnameescape(a:filename)
      catch /^Vim(edit):E37/
        echohl ErrorMsg | echomsg 'No write since last change' | echohl None
        return 0
      endtry
    endif
    call cursor(a:line, a:column)
    return 1
  endif
endfunction

function! OmniSharp#FindSymbol(...) abort
  let filter = a:0 > 0 ? a:1 : ''
  if !OmniSharp#ServerIsRunning()
    return
  endif
  let quickfixes = pyeval(printf('findSymbols(%s)', string(filter)))
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
    call setqflist(quickfixes)
    botright cwindow 4
  endif
endfunction

function! OmniSharp#FindType() abort
  if g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findtype']])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#init(ctrlp#OmniSharp#findtype#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#findtypes()
  else
    call setqflist(quickfixes)
    botright cwindow 4
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
  let v = g:OmniSharp_server_type ==# 'roslyn' ? 'v2' : 'v1'
  let s:actions = pyeval(printf('getCodeActions("normal", %s)', string(v)))

  " v:t_func was added in vim8 - this form is backwards-compatible
  if a:0 && type(a:1) == type(function("tr"))
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
  let v = g:OmniSharp_server_type ==# 'roslyn' ? 'v2' : 'v1'
  if exists('s:actions')
    let actions = s:actions
  else
    let actions = pyeval(printf('getCodeActions(%s, %s)', string(a:mode), string(v)))
  endif
  if empty(actions)
    echo 'No code actions found'
    return
  endif
  if g:OmniSharp_selector_ui ==? 'unite'
    let context = {'empty': 0, 'auto_resize': 1}
    call unite#start([['OmniSharp/findcodeactions', a:mode, actions, v]], context)
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
      call add(message, printf(' %2d. %s', i, v ==# 'v1' ? action : action.Name))
    endfor
    call add(message, 'Enter an action number, or just hit Enter to cancel: ')
    let selection = str2nr(input(join(message, "\n")))
    if type(selection) == type(0) && selection > 0 && selection <= i
      if v ==# 'v1'
        let command = printf('runCodeAction(%s, %d)', string(a:mode), selection - 1)
      else
        let action = actions[selection - 1]
        let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
        let command = printf('runCodeAction(''%s'', ''%s'', ''v2'')', a:mode, command)
      endif
      if !pyeval(command)
        echo 'No action taken'
      endif
    endif
  endif
endfunction

function! OmniSharp#GetIssues() abort
  if pumvisible()
    return get(b:, 'issues', [])
  endif
  if g:serverSeenRunning == 1
    let b:issues = pyeval('getCodeIssues()')
  endif
  return get(b:, 'issues', [])
endfunction

function! OmniSharp#FixIssue() abort
  python fixCodeIssue()
endfunction

function! OmniSharp#FindSyntaxErrors() abort
  if pumvisible()
    return get(b:, 'syntaxerrors', [])
  endif
  if bufname('%') ==# ''
    return []
  endif
  if g:serverSeenRunning == 1
    let b:syntaxerrors = pyeval('findSyntaxErrors()')
  endif
  return get(b:, 'syntaxerrors', [])
endfunction

function! OmniSharp#FindSemanticErrors() abort
  if pumvisible()
    return get(b:, 'semanticerrors', [])
  endif
  if bufname('%') ==# ''
    return []
  endif
  if g:serverSeenRunning == 1
    let b:semanticerrors = pyeval('findSemanticErrors()')
  endif
  return get(b:, 'semanticerrors', [])
endfunction

function! OmniSharp#CodeCheck() abort
  if pumvisible()
    return get(b:, 'codecheck', [])
  endif
  if bufname('%') ==# ''
    return []
  endif
  if g:serverSeenRunning == 1
    let b:codecheck = pyeval('codeCheck()')
  endif
  return get(b:, 'codecheck', [])
endfunction

function! OmniSharp#TypeLookupWithoutDocumentation() abort
  call OmniSharp#TypeLookup('False')
endfunction

function! OmniSharp#TypeLookupWithDocumentation() abort
  call OmniSharp#TypeLookup('True')
endfunction

function! OmniSharp#TypeLookup(includeDocumentation) abort
  let type = ''

  if g:OmniSharp_typeLookupInPreview || a:includeDocumentation ==# 'True'
    let s:documentation = ''
    python typeLookup("type")
    let doc = get(s:, 'documentation', '')
    if len(doc) > 0
      let doc = "\n\n" . doc
    endif
    call s:writeToPreview(type . doc)
  else
    let line = line('.')
    let found_line_in_loc_list = 0
    "don't display type lookup if we have a syntastic error
    if exists(':SyntasticCheck')
      SyntasticSetLoclist
      for issue in getloclist(0)
        if issue['lnum'] == line
          let found_line_in_loc_list = 1
          break
        endif
      endfor
    endif
    if found_line_in_loc_list == 0
      python typeLookup("type")
      call OmniSharp#Echo(type)
    endif
  endif
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
  let result = s:json_decode(pyeval('renameTo()'))

  let save_lazyredraw = &lazyredraw
  let save_eventignore = &eventignore
  let buf = bufnr('%')
  let curpos = getpos('.')
  try
    set lazyredraw eventignore=all
    for change in result.Changes
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
      execute buf 'buffer'
    endif
    call setpos('.', curpos)
    silent update
    let &eventignore = save_eventignore
    silent edit  " reload to apply syntax
    let &lazyredraw = save_lazyredraw
  endtry
endfunction

function! OmniSharp#Build() abort
  let qf_taglist = pyeval('build()')

  " Place the tags in the quickfix window, if possible
  if len(qf_taglist) > 0
    call setqflist(qf_taglist)
    botright cwindow 4
  endif
endfunction

function! OmniSharp#BuildAsync() abort
  python buildcommand()
  let &l:makeprg=b:buildcommand
  setlocal errorformat=\ %#%f(%l\\\,%c):\ %m
  Make
endfunction

function! OmniSharp#RunTests(mode) abort
  wall
  python buildcommand()

  if a:mode !=# 'last'
    python getTestCommand()
  endif

  let s:cmdheight=&cmdheight
  set cmdheight=5
  let b:dispatch = b:buildcommand . ' && ' . s:testcommand
  if executable('sed')
    " don't match on <filename unknown>:0
    let b:dispatch .= ' | sed "s/:0//"'
  endif
  let &l:makeprg=b:dispatch
  "errorformat=msbuild,nunit stack trace
  setlocal errorformat=\ %#%f(%l\\\,%c):\ %m,%m\ in\ %#%f:%l
  Make
  let &cmdheight = s:cmdheight
endfunction

function! OmniSharp#EnableTypeHighlightingForBuffer() abort
  highlight default link csUserType Type
  if !empty(s:allUserTypes)
    exec 'syn keyword csUserType ' . s:allUserTypes
  endif
  highlight default link csUserInterface Include
  if !empty(s:allUserInterfaces)
    exec 'syn keyword csUserInterface ' . s:allUserInterfaces
  endif
  highlight default link csUserAttribute Include
  if !empty(s:allUserAttributes)
    exec 'syn keyword csUserAttribute ' . s:allUserAttributes
  endif
endfunction

function! OmniSharp#EnableTypeHighlighting() abort
  if !OmniSharp#ServerIsRunning()
    return
  endif

  if g:OmniSharp_server_type ==# 'roslyn'
    python lookupAllUserTypes()
  else
    python lookupAllUserTypesLegacy()
  endif

  let startBuf = bufnr('%')
  " Perform highlighting for existing buffers
  bufdo if &ft == 'cs' | call OmniSharp#EnableTypeHighlightingForBuffer() | endif
  exec 'b '. startBuf

  call OmniSharp#EnableTypeHighlightingForBuffer()

  augroup _omnisharp
    autocmd!
    autocmd BufRead *.cs call OmniSharp#EnableTypeHighlightingForBuffer()
  augroup END
endfunction

function! OmniSharp#ReloadSolution() abort
  python getResponse("/reloadsolution")
endfunction

function! OmniSharp#UpdateBuffer() abort
  if OmniSharp#BufferHasChanged() == 1
    python getResponse("/updatebuffer")
  endif
endfunction

function! OmniSharp#BufferHasChanged() abort
  if g:serverSeenRunning == 1
    if b:changedtick != get(b:, 'Omnisharp_UpdateChangeTick', -1)
      let b:Omnisharp_UpdateChangeTick = b:changedtick
      return 1
      echoerr 'wtf'
    endif
  endif
  return 0
endfunction

function! OmniSharp#CodeFormat() abort
  python codeFormat()
endfunction

function! OmniSharp#FixUsings() abort
  let qf_taglist = pyeval('fix_usings()')

  if len(qf_taglist) > 0
    call setqflist(qf_taglist)
    botright cwindow
  endif
endfunction

function! OmniSharp#ServerIsRunning() abort
  try
    python vim.command("let s:alive = '" + getResponse("/checkalivestatus", None, 0.2) + "'");
    return s:alive ==# 'true'
  catch
    return 0
  endtry
endfunction

function! OmniSharp#StartServerIfNotRunning() abort
  if !OmniSharp#ServerIsRunning()
    call OmniSharp#StartServer()
    if g:Omnisharp_stop_server==2
      au VimLeavePre * call OmniSharp#StopServer()
    endif
  endif
endfunction

function! OmniSharp#FugitiveCheck() abort
  if match( expand( '<afile>:p' ), 'fugitive:///' ) == 0
    return 1
  else
    return 0
  endif
endfunction

function! OmniSharp#StartServer() abort
  if OmniSharp#FugitiveCheck()
    return
  endif

  let solution_files = s:find_solution_files()
  if empty(solution_files)
    return
  endif

  let l:command = []

  if len(solution_files) == 1
    let l:command = OmniSharp#util#get_start_cmd(solution_files[0])
  elseif g:OmniSharp_sln_list_name !=# ''
    echom 'Started with sln: ' . g:OmniSharp_sln_list_name
    let l:command = OmniSharp#util#get_start_cmd(g:OmniSharp_sln_list_name)
  elseif g:OmniSharp_sln_list_index > -1 &&
  \     g:OmniSharp_sln_list_index < len(solution_files)
    echom 'Started with sln: ' . solution_files[g:OmniSharp_sln_list_index]
    let l:command = OmniSharp#util#get_start_cmd(solution_files[g:OmniSharp_sln_list_index])
  else
    echom 'sln: ' . g:OmniSharp_sln_list_name
    let index = 1
    if g:OmniSharp_autoselect_existing_sln
      for solutionfile in solution_files
        if index( g:OmniSharp_running_slns, solutionfile ) >= 0
          return
        endif
      endfor
    endif

    for solutionfile in solution_files
      echo index . ' - '. solutionfile
      let index = index + 1
    endfor

    let option = input('Choose a solution file and press enter ') - 0

    if option == 0 || option > len(solution_files)
      return
    endif

    let l:command = OmniSharp#util#get_start_cmd(solution_files[option - 1])
  endif

  if l:command ==# []
    echoerr 'Could not determinet the command to start the OmniSharp server!'
    return
  endif

  call OmniSharp#proc#RunAsyncCommand(command)
endfunction

function! OmniSharp#AddToProject() abort
  python getResponse("/addtoproject")
endfunction

function! OmniSharp#AskStopServerIfRunning() abort
  if OmniSharp#ServerIsRunning()
    call inputsave()
    let choice = input('Do you want to stop the OmniSharp server? (Y/n): ')
    call inputrestore()
    if choice !=? 'n'
      call OmniSharp#StopServer(1)
    endif
  endif
endfunction

function! OmniSharp#StopServer(...) abort
  if a:0 > 0
    let force = a:1
  else
    let force = 0
  endif

  if force || OmniSharp#ServerIsRunning()
    python getResponse("/stopserver")
    call OmniSharp#proc#StopJob()
    let g:OmniSharp_running_slns = []
  endif
endfunction

function! OmniSharp#AddReference(reference) abort
  if findfile(fnamemodify(a:reference, ':p')) !=# ''
    let a:ref = fnamemodify(a:reference, ':p')
  else
    let a:ref = a:reference
  endif
  python addReference()
endfunction

function! OmniSharp#AppendCtrlPExtensions() abort
  " Don't override settings made elsewhere
  if !exists('g:ctrlp_extensions')
    let g:ctrlp_extensions = []
  endif
  if !exists('g:OmniSharp_ctrlp_extensions_added')
    let g:OmniSharp_ctrlp_extensions_added = 1
    let g:ctrlp_extensions += ['findtype', 'findsymbols', 'findcodeactions']
  endif
endfunction

function! OmniSharp#ExpandAutoCompleteSnippet()
  if !g:OmniSharp_want_snippet
    return
  endif

  if empty(globpath(&runtimepath, 'plugin/UltiSnips.vim'))
    echoerr 'g:OmniSharp_want_snippet is enabled but this requires the UltiSnips plugin and it is not installed.'
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

function! s:find_solution_files() abort
  "get the path for the current buffer
  let dir = expand('%:p:h')
  let lastfolder = ''
  let solution_files = []

  while dir !=# lastfolder
    if empty(solution_files)
      let solution_files += s:globpath(dir, '*.sln')
      if g:OmniSharp_server_type ==# 'roslyn'
        let solution_files += s:globpath(dir, 'project.json')
      endif

      call filter(solution_files, 'filereadable(v:val)')
    endif

    if g:OmniSharp_server_type ==# 'roslyn' && g:OmniSharp_prefer_global_sln
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

function! s:json_decode(json) abort
  if a:json == ''
    throw 'Empty JSON response from server'
  endif

  let [null, true, false] = [0, 1, 0]
  try
    sandbox return eval(a:json)
  catch
    throw 'Invalid JSON response from server: ' . a:json
  endtry
endfunction

" Manually write content to the preview window.
" Opens a preview window to a scratch buffer named '__OmniSharpScratch__'
function! s:writeToPreview(content)
  silent pedit __OmniSharpScratch__
  silent wincmd P
  setlocal modifiable noreadonly
  setlocal nobuflisted buftype=nofile bufhidden=wipe
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
