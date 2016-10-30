if !(has('python') || has('python3'))
  finish
endif

let s:pycmd = has('python3') ? 'python3' : 'python'
let s:pyfile = has('python3') ? 'py3file' : 'pyfile'
if exists('*py3eval')
  let s:pyeval = function('py3eval')
elseif exists('*pyeval')
  let s:pyeval = function('pyeval')
else
  exec s:pycmd 'import json, vim'
  function! s:pyeval(e)
    exec s:pycmd 'vim.command("return " + json.dumps(eval(vim.eval("a:e"))))'
  endfunction
endif

let s:save_cpo = &cpo
set cpo&vim

let s:dir_separator = fnamemodify('.', ':p')[-1 :]
let s:server_files = '*.sln'
let s:roslyn_server_files = 'project.json'
let s:allUserTypes = ''
let s:allUserInterfaces = ''
let s:generated_snippets = {}
let s:omnisharp_last_completion_dictionary = {}
let g:serverSeenRunning = 0
let g:omnisharp_debug = 1

function! s:debug(message)
  if g:omnisharp_debug == 1
    echom "DEBUG: " . string(a:message)
  endif
endfunction

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
    let omnisharp_last_completion_result = s:pyeval('Completion().get_completions("s:column", "a:base")')
    let s:omnisharp_last_completion_dictionary = {}
    for completion in omnisharp_last_completion_result
        let s:omnisharp_last_completion_dictionary[get(completion, 'word')] = completion
    endfor
    return omnisharp_last_completion_result
  endif
endfunction

function! OmniSharp#FindUsages() abort
  let qf_taglist = s:pyeval('omnisharp.findUsages()')

  " Place the tags in the quickfix window, if possible
  if len(qf_taglist) > 0
    call setqflist(qf_taglist)
    botright cwindow 4
  else
    echo 'No usages found'
  endif
endfunction

function! OmniSharp#FindImplementations() abort
  let qf_taglist = s:pyeval('omnisharp.findImplementations()')

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
  let qf_taglist = s:pyeval('omnisharp.findMembers()')

  " Place the tags in the quickfix window, if possible
  if len(qf_taglist) > 1
    call setqflist(qf_taglist)
    botright cwindow 4
  endif
endfunction

function! OmniSharp#NavigateUp() abort
  if g:OmniSharp_server_type ==# 'roslyn'
    let qf_tag = s:pyeval('omnisharp.navigateUp()')
    call cursor(qf_tag.Line, qf_tag.Column)
  else
    let qf_taglist = s:pyeval('omnisharp.findMembers()')
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
    let qf_tag = s:pyeval('omnisharp.navigateDown()')
    call cursor(qf_tag.Line, qf_tag.Column)
  else
    let qf_taglist = s:pyeval('omnisharp.findMembers()')
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
  exec s:pycmd 'omnisharp.gotoDefinition()'
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

function! OmniSharp#SelectorPluginError()
  echoerr 'No selector plugin found.  Please install unite.vim, ctrlp.vim or fzf.vim'
endfunction

function! OmniSharp#FindSymbol() abort
  if g:OmniSharp_selector_ui ==? 'unite'
    call unite#start([['OmniSharp/findsymbols']])
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#init(ctrlp#OmniSharp#findsymbols#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#findsymbols()
  else
    call OmniSharp#SelectorPluginError()
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
    call OmniSharp#SelectorPluginError()
  endif
endfunction

function! OmniSharp#GetCodeActions(mode) range abort
  if g:OmniSharp_selector_ui ==? 'unite'
    let context = {'empty': 0, 'auto_resize': 1}
    call unite#start([['OmniSharp/findcodeactions', a:mode]], context)
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    let actions = s:pyeval(printf('omnisharp.getCodeActions(%s)', string(a:mode)))
    if empty(actions)
      echo 'No code actions found'
      return
    endif
    call ctrlp#OmniSharp#findcodeactions#setactions(a:mode, actions)
    call ctrlp#init(ctrlp#OmniSharp#findcodeactions#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#getcodeactions(a:mode)
  else
    call OmniSharp#SelectorPluginError()
  endif
endfunction

function! OmniSharp#GetIssues() abort
  if pumvisible()
    return get(b:, 'issues', [])
  endif
  if g:serverSeenRunning == 1
    let b:issues = s:pyeval('omnisharp.getCodeIssues()')
  endif
  return get(b:, 'issues', [])
endfunction

function! OmniSharp#FixIssue() abort
  exec s:pycmd 'omnisharp.fixCodeIssue()'
endfunction

function! OmniSharp#FindSyntaxErrors() abort
  if pumvisible()
    return get(b:, 'syntaxerrors', [])
  endif
  if bufname('%') ==# ''
    return []
  endif
  if g:serverSeenRunning == 1
    let b:syntaxerrors = s:pyeval('omnisharp.findSyntaxErrors()')
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
    let b:semanticerrors = s:pyeval('omnisharp.findSemanticErrors()')
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
    let b:codecheck = s:pyeval('omnisharp.codeCheck()')
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
    exec s:pycmd 'omnisharp.typeLookup("type")'
    let preWinNr = winnr()
    call s:GoScratch()
    exec s:pycmd 'vim.current.window.height = 5'
    let doc = get(s:, 'documentation', '')
    set modifiable
    exec s:pycmd 'vim.current.buffer[:] = ["' . type . '"] + """' . doc . '""".splitlines()'
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
      exec s:pycmd 'omnisharp.typeLookup("type")'
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
  let result = s:json_decode(s:pyeval('omnisharp.renameTo()'))

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
  let qf_taglist = s:pyeval('omnisharp.build()')

  " Place the tags in the quickfix window, if possible
  if len(qf_taglist) > 0
    call setqflist(qf_taglist)
    botright cwindow 4
  endif
endfunction

function! OmniSharp#BuildAsync() abort
  exec s:pycmd 'omnisharp.buildcommand()'
  let &l:makeprg=b:buildcommand
  setlocal errorformat=\ %#%f(%l\\\,%c):\ %m
  Make
endfunction

function! OmniSharp#RunTests(mode) abort
  wall
  exec s:pycmd 'omnisharp.buildcommand()'

  if a:mode !=# 'last'
    exec s:pycmd 'omnisharp.getTestCommand()'
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

  exec s:pycmd 'omnisharp.lookupAllUserTypes()'

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
  exec s:pycmd 'omnisharp.getResponse("/reloadsolution")'
endfunction

function! OmniSharp#UpdateBuffer() abort
  if OmniSharp#BufferHasChanged() == 1
    exec s:pycmd 'omnisharp.getResponse("/updatebuffer")'
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
  exec s:pycmd 'omnisharp.codeFormat()'
endfunction

function! OmniSharp#FixUsings() abort
  let qf_taglist = s:pyeval('omnisharp.fix_usings()')

  if len(qf_taglist) > 0
    call setqflist(qf_taglist)
    botright cwindow
  endif
endfunction

function! OmniSharp#ServerIsRunning() abort
  try
    let s:alive = s:pyeval('omnisharp.getResponse("/checkalivestatus", None, 0.2)')
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

  let command = [g:OmniSharp_server_path,
               \ '-p', port,
               \ '-s', solutionPath]

  if g:OmniSharp_server_type !=# 'roslyn'
    call add(command, OmniSharp#ResolveLocalConfig(solutionPath))
  endif
  if !has('win32') && !has('win32unix') && g:OmniSharp_server_type !=# 'roslyn'
    call insert(command, 'mono')
  endif

  call OmniSharp#RunAsyncCommand(command)
endfunction

function! Receive(job_id, data, event)
  if g:omnisharp_debug == 1
    echom printf('%s: %s',a:event,string(a:data))
  endif
endfunction

function! ReceiveVim(channel, message)
  if g:omnisharp_debug == 1
      echom printf('%s: %s', string(a:channel), string(a:message))
  endif
endfunction

function! OmniSharp#RunAsyncCommand(command) abort
  let is_vimproc = 0
  silent! let is_vimproc = vimproc#version()
  let command = a:command
  if exists('*jobstart')
    call s:debug("Using Neovim jobstart to start the following command:")
    call s:debug(command)
    call jobstart(command, {'on_stdout': 'Receive'})
  elseif exists('*job_start')
    call s:debug("Using vim job_start to start the following command:")
    call s:debug(command)
    let job = job_start(join(command, ' '), {'out_cb': 'ReceiveVim'})
  elseif exists(':Dispatch') == 2
    call dispatch#start(join(command, ' '), {'background': 1})
  elseif is_vimproc
    call vimproc#system_gui(substitute(join(command, ' '), '\\', '\/', 'g'))
  else
    echoerr 'Please use neovim, or vim 8.0+ or install either vim-dispatch or vimproc plugin to use this feature'
  endif
endfunction

function! OmniSharp#AddToProject() abort
  exec s:pycmd 'omnisharp.getResponse("/addtoproject")'
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
    exec s:pycmd 'omnisharp.getResponse("/stopserver")'
    let g:OmniSharp_running_slns = []
  endif
endfunction

function! OmniSharp#AddReference(reference) abort
  if findfile(fnamemodify(a:reference, ':p')) !=# ''
    let a:ref = fnamemodify(a:reference, ':p')
  else
    let a:ref = a:reference
  endif
  exec s:pycmd 'omnisharp.addReference()'
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

  if !exists("*UltiSnips#AddSnippetWithPriority")
    echoerr "g:OmniSharp_want_snippet is enabled but this requires the UltiSnips plugin and it is not installed."
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

    if has_key(s:omnisharp_last_completion_dictionary, completion)
      let snippet = get(get(s:omnisharp_last_completion_dictionary, completion, ''), 'snip','')
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

" vim:nofen:fdl=0:ts=2:sw=2:sts=2
