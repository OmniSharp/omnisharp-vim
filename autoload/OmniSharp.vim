if !has('python')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

let s:dir_separator = fnamemodify('.', ':p')[-1 :]
let s:server_files = '*.sln'
let s:roslyn_server_files = 'project.json'
let s:allUserTypes = ''
let s:allUserInterfaces = ''
let g:serverSeenRunning = 0

function! OmniSharp#Complete(findstart, base) abort
  if a:findstart
    "store the current cursor position
    let s:column = col('.')
    "locate the start of the word
    let line = getline('.')
    let start = col('.') - 1
    let s:textBuffer = getline(1, '$')
    while start > 0 && line[start - 1] =~# '\v[a-zA-z0-9_]'
      let start -= 1
    endwhile

    return start
  else
    return pyeval('Completion().get_completions("s:column", "a:base")')
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
    if a:filename !=# bufname('%')
      exec 'e! ' . fnameescape(a:filename)
    endif
    "row is 1 based, column is 0 based
    call cursor(a:line, a:column)
  endif
endfunction

function! OmniSharp#FindSymbol() abort
  if g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findsymbols']])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#init(ctrlp#OmniSharp#findsymbols#id())
  else
    echo 'No selector plugin found.  Please install unite.vim or ctrlp.vim'
  endif
endfunction

function! OmniSharp#FindType() abort
  if g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findtype']])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#init(ctrlp#OmniSharp#findtype#id())
  else
    echo 'No selector plugin found.  Please install unite.vim or ctrlp.vim'
  endif
endfunction

function! OmniSharp#GetCodeActions(mode) range abort
  if g:OmniSharp_selector_ui ==? 'unite'
    let context = {'empty': 0, 'auto_resize': 1}
    call unite#start([['OmniSharp/findcodeactions', a:mode]], context)
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    let actions = pyeval(printf('getCodeActions(%s)', string(a:mode)))
    if empty(actions)
      echo 'No code actions found'
      return
    endif
    call ctrlp#OmniSharp#findcodeactions#setactions(a:mode, actions)
    call ctrlp#init(ctrlp#OmniSharp#findcodeactions#id())
  else
    echo 'No selector plugin found.  Please install unite.vim or ctrlp.vim'
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

" Jump to first scratch window visible in current tab, or create it.
" This is useful to accumulate results from successive operations.
" Global function that can be called from other scripts.
function! s:GoScratch() abort
  if bufwinnr('__OmniSharpScratch__') == -1
    "botright new __OmniSharpScratch__
    botright split __OmniSharpScratch__
    setlocal buftype=nofile bufhidden=hide noswapfile nolist nobuflisted nospell
  endif
  for i in range(1, winnr('$'))
    execute i . 'wincmd w'
    if &buftype ==# 'nofile' && bufname('%') ==# '__OmniSharpScratch__'
      break
    endif
  endfor
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
    python typeLookup("type")
    let preWinNr = winnr()
    call s:GoScratch()
    python vim.current.window.height = 5
    set modifiable
    exec 'python vim.current.buffer[:] = ["' . type . '"] + """' . s:documentation . '""".splitlines()'
    set nomodifiable
    "Return to original window
    execute preWinNr . 'wincmd w'
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
  let curpos = getcurpos()
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
  hi link CSharpUserType Type
  exec 'syn keyword CSharpUserType ' . s:allUserTypes
  exec 'syn keyword csInterfaceDeclaration ' . s:allUserInterfaces
endfunction

function! OmniSharp#EnableTypeHighlighting() abort

  if !OmniSharp#ServerIsRunning() || !empty(s:allUserTypes)
    return
  endif

  python lookupAllUserTypes()

  let startBuf = bufnr('%')
  " Perform highlighting for existing buffers
  bufdo if &ft == 'cs' | call OmniSharp#EnableTypeHighlightingForBuffer() | endif
exec 'b '. startBuf

call OmniSharp#EnableTypeHighlightingForBuffer()

augroup _omnisharp
  au!
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
  if len(solution_files) == 1
    call OmniSharp#StartServerSolution(solution_files[0])
  elseif g:OmniSharp_sln_list_name !=# ''
    echom 'Started with sln: ' . g:OmniSharp_sln_list_name
    call OmniSharp#StartServerSolution( g:OmniSharp_sln_list_name )
  elseif g:OmniSharp_sln_list_index > -1 &&
  \     g:OmniSharp_sln_list_index < len(solution_files)
    echom 'Started with sln: ' . solution_files[g:OmniSharp_sln_list_index]
    call OmniSharp#StartServerSolution( solution_files[g:OmniSharp_sln_list_index]  )
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

    call OmniSharp#StartServerSolution(solution_files[option - 1])
  endif
endfunction

function! OmniSharp#ResolveLocalConfig(solutionPath) abort
  let result = ''
  let configPath = fnamemodify(a:solutionPath, ':p:h')
  \ . s:dir_separator
  \ . g:OmniSharp_server_config_name

  if filereadable(configPath)
    let result = ' -config ' . shellescape(configPath, 1)
  endif
  return result
endfunction

function! OmniSharp#StartServerSolution(solutionPath) abort
  let solutionPath = a:solutionPath
  if fnamemodify(solutionPath, ':t') ==? s:roslyn_server_files
    let solutionPath = fnamemodify(solutionPath, ':h')
  endif
  let g:OmniSharp_running_slns += [solutionPath]
  let port = exists('b:OmniSharp_port') ? b:OmniSharp_port : g:OmniSharp_port
  let command = shellescape(g:OmniSharp_server_path, 1)
  \ . ' -p ' . port
  \ . ' -s ' . shellescape(solutionPath, 1)
  if g:OmniSharp_server_type !=# 'roslyn'
    let command .= OmniSharp#ResolveLocalConfig(solutionPath)
  endif
  if !has('win32') && !has('win32unix') && g:OmniSharp_server_type !=# 'roslyn'
    let command = 'mono ' . command
  endif
  call OmniSharp#RunAsyncCommand(command)
endfunction

function! OmniSharp#RunAsyncCommand(command) abort
  let is_vimproc = 0
  silent! let is_vimproc = vimproc#version()
  if exists(':Dispatch') == 2
    call dispatch#start(a:command, {'background': 1})
  else
    if is_vimproc
      call vimproc#system_gui(substitute(a:command, '\\', '\/', 'g'))
    else
      echoerr 'Please install either vim-dispatch or vimproc plugin to use this feature'
    endif
  endif
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

function! s:find_solution_files() abort
  "get the path for the current buffer
  let dir = expand('%:p:h')
  let solution_files = []

  while empty(solution_files)
    let solution_files += s:globpath(dir , '*.sln')
    if g:OmniSharp_server_type ==# 'roslyn'
      let solution_files += s:globpath(dir, 'project.json')
    endif

    call filter(solution_files, 'filereadable(v:val)')

    let lastfolder = dir
    let dir = fnamemodify(dir, ':h')
    if dir ==# lastfolder
      break
    endif
  endwhile

  if empty(solution_files) && g:OmniSharp_start_without_solution
    let solution_files = ['.']
  endif

  return solution_files
endfunction

function! s:json_decode(json) abort
  let [null, true, false] = [0, 1, 0]
  sandbox return eval(a:json)
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
