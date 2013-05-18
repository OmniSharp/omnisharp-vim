let s:save_cpo = &cpo
set cpo&vim

let s:omnisharp_server = join([expand('<sfile>:p:h:h'), 'server', 'OmniSharp', 'bin', 'Debug', 'OmniSharp.exe'], '/')

function! s:getCodeActions()
  let response = OmniSharp#request#getcodeactions()
  if ! empty(response)
    let index = 1
    for action in response.codeactions
      call OmniSharp#print(printf("%d :  %s", index, action))
      if 0 < len(response.codeactions)
        return 1
      endif
      let index += 1
    endfor
  endif
  return 0
endfunction

function! s:runCodeAction(option)
  let parameters = {}
  let parameters['codeaction'] = a:option
  let response = OmniSharp#request#runcodeaction(parameters)
  if empty(response.text)
    return
  endif
  let lines = split(response.text,"\n")
  let pos = getpos('.')
  call s:setCurrBuffer(split(lines,"\n"))
  call setpos('.',pos)
endfunction

function! s:setCurrBuffer(lines)
  silent % delete _
  silent put =a:lines
  silent 1 delete _
endfunction

function! OmniSharp#Complete(findstart, base)
  if a:findstart
    "store the current cursor position
    let s:column = col(".")
    "locate the start of the word
    let line = getline('.')
    let start = col(".") - 1
    let s:textBuffer = getline(1,'$')
    while start > 0 && line[start - 1] =~ '\v[a-zA-z0-9_]'
      let start -= 1
    endwhile

    return start
  else
    let complete_obj = OmniSharp#complete#getCompletions(s:column, a:base, s:textBuffer)
    " call writefile([s:column,string(s:textBuffer),string(complete_obj)],expand('~/a.log'))
    if len(complete_obj.candidates) == 0
      return -3
    endif
    return complete_obj.candidates
  endif
endfunction

function! OmniSharp#FindUsages()
  let complete_obj = OmniSharp#complete#findUsages()

  " Place the tags in the quickfix window, if possible
  if len(complete_obj.candidates) > 0
    call setqflist(complete_obj.candidates)
    copen 4
  else
    call OmniSharp#print("No usages found")
  endif
endfunction

function! OmniSharp#FindImplementations()
  let complete_obj = OmniSharp#complete#findimplementations()

  if 1 == len(complete_obj.candidates)
    let cand = complete_obj.candidates[0]
    if !empty(cand.filename)
      if fnamemodify(cand.filename,':p') != expand('%:p')
        execute printf('e %s', cand.filename)
      endif
      " row is 1 based, column is 0 based
      call setpos('.',[ 0, cand.line, cand.column - 1, 0])
    endif
  elseif 1 < len(complete_obj.candidates)
    " Place the tags in the quickfix window, if possible
    call setqflist(complete_obj.candidates)
    copen 4
  endif
endfunction

function! OmniSharp#GotoDefinition()
  let response = OmniSharp#request#gotodefinition()
  if ! empty(response)
    if ! empty(response.filename)
      if fnamemodify(response.filename,':p') != expand('%:p')
        execute printf('e %s', response.filename)
      endif
      " row is 1 based, column is 0 based
      call setpos('.',[ 0, response.line, response.column - 1, 0])
    endif
  endif
endfunction

function! OmniSharp#GetCodeActions()
  if s:getCodeActions()
    return 0
  endif

  let option = nr2char(getchar())
  if option < '0' || option > '9'
    return 1
  endif

  call s:runCodeAction(option)
endfunction

function! OmniSharp#FindSyntaxErrors()
  if empty(bufname('%'))
    return
  endif
  let complete_obj = OmniSharp#complete#findSyntaxErrors()

  " Place the tags in the quickfix window, if possible
  if len(complete_obj.candidates) > 0
    call setqflist(complete_obj.candidates)
    copen 4
  else
    cclose
  endif
endfunction

function! OmniSharp#TypeLookup()
  let response = OmniSharp#request#typelookup()
  let type = empty(response) ? '' : response[0].type

  if g:OmniSharp_typeLookupInPreview
    "Try to go to preview window
    silent! wincmd P
    if !&previewwindow
      "If couldn't goto the preview window, then there is no open preview
      "window, so make one
      pedit!
      wincmd P
      setlocal winheight=3
      badd [Scratch]
      buff \[Scratch\]

      setlocal noswapfile
      setlocal filetype=cs
      "When looking for the buffer to place completion details in Vim
      "looks for the following options to set
      setlocal buftype=nofile
      setlocal bufhidden=wipe
    endif
    "Replace the contents of the preview window
    set modifiable
    call s:setCurrBuffer([type])
    set nomodifiable
    "Return to original window
    wincmd p
  else
    call OmniSharp#print(type)
  endif
endfunction

function! OmniSharp#Rename()
  let a:renameto = inputdialog("Rename to:")
  if a:renameto != ''
    call OmniSharp#RenameTo(a:renameto)
  endif
endfunction

function! OmniSharp#RenameTo(renameto)
  let parameters = {}
  let parameters['renameto'] = a:renameto
  let response = OmniSharp#request#rename(parameters)
  let currentBuffer = expand('%')
  let pos = getpos('.')
  for change in response[0].changes
    let lines = split(change.buffer,"\n")
    if ! empty(change.filename)
      execute 'argadd ' . change.filename
      for buf in filter(range(1, bufnr("$")),"bufexists(v:val) && buflisted(v:val)")
        if bufname(bnum) == filename
          execute 'b ' . change.filename
          call s:setCurrBuffer(lines)
          break
        endif
      endfor
    endif
    undojoin
  endfor
  execute 'b ' . currentBuffer
  call setpos('.',pos)
endfunction

function! OmniSharp#Build()
  let complete_obj = OmniSharp#complete#build()
  if complete_obj.response[0].success
    call OmniSharp#print("Build succeeded")
  else
    call OmniSharp#print("Build failed")
  endif

  " Place the tags in the quickfix window, if possible
  if len(complete_obj.candidates) > 0
    call setqflist(complete_obj.candidates)
    copen 4
  endif
endfunction

function! OmniSharp#ReloadSolution()
  call OmniSharp#request#reloadsolution()
endfunction

function! OmniSharp#CodeFormat()
  let response = OmniSharp#request#codeformat()
  if ! empty(response)
    call s:setCurrBuffer(split(response[0].buffer,"\n"))
  endif
endfunction

function! OmniSharp#StartServer()
  "get the path for the current buffer
  let folder = expand('%:p:h')
  let solutionfiles = globpath(folder, "*.sln")

  while (solutionfiles == '')
    let lastfolder = folder
    "traverse up a level

    let folder = fnamemodify(folder, ':p:h:h')
    if folder == lastfolder
      break
    endif
    let solutionfiles = globpath(folder , "*.sln")
  endwhile

  if solutionfiles != ''
    let array = split(solutionfiles, '\n')
    if len(array) == 1
      call OmniSharp#StartServerSolution(array[0])
    else
      let index = 1
      for solutionfile in array
        call OmniSharp#print(index . ' - '. solutionfile)
        let index += 1
      endfor
      call OmniSharp#print('Choose a solution file')
      let option = nr2char(getchar())
      if option < '1' || option > '9'
        return
      endif
      if option > len(array)
        return
      endif

      call OmniSharp#StartServerSolution(array[option - 1])
    endif
  else
    call OmniSharp#print("Did not find a solution file")
  endif
endfunction

function! OmniSharp#StartServerSolution(solutionPath)
  let command = shellescape(s:omnisharp_server,1) . ' -s ' . fnamemodify(a:solutionPath, ':8')
  call dispatch#start(command, {'background': has('win32') ? 0 : 1})
endfunction

function! OmniSharp#AddToProject()
  call OmniSharp#request#addtoproject()
endfunction

function! OmniSharp#print(msg)
  echo a:msg
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
