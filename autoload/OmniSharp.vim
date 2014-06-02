let s:save_cpo = &cpo
set cpo&vim

let s:omnisharp_server = join([expand('<sfile>:p:h:h'), 'server', 'OmniSharp', 'bin', 'Debug', 'OmniSharp.exe'], '/')
let s:allUserTypes = ''
let s:allUserInterfaces = ''
let g:serverSeenRunning = 0
let g:codeactionsinprogress = 0

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
		return pyeval('Completion().get_completions("s:column", "a:base")')
	endif
endfunction

function! OmniSharp#FindUsages()
	let qf_taglist = pyeval('findUsages()')

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	else
		echo "No usages found"
	endif
endfunction

function! OmniSharp#FindImplementations()
	let qf_taglist = pyeval("findImplementations()")

	if len(qf_taglist) == 0
        echo "No implementations found"
    endif 

	if len(qf_taglist) == 1
        let usage = qf_taglist[0]
        call OmniSharp#JumpToLocation(usage.filename, usage.lnum, usage.col)
    endif

	if len(qf_taglist) > 1
		call setqflist(qf_taglist)
		copen 4
	endif
endfunction

function! OmniSharp#FindMembers()
	let qf_taglist = pyeval("findMembers()")

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 1
		call setqflist(qf_taglist)
		copen 4
	endif
endfunction

function! OmniSharp#GotoDefinition()
	python gotoDefinition()
endfunction

function! OmniSharp#JumpToLocation(filename, line, column)
    if(a:filename != '')
        if a:filename != bufname('%')
            exec 'e! ' . fnameescape(a:filename)
        endif
        "row is 1 based, column is 0 based
        call cursor(a:line, a:column)
    endif
endfunction

function! OmniSharp#GetCodeActions(mode)
    " I can't figure out how to prevent this method
    " being called multiple times for each line in
    " the visual selection. This is a workaround.
    if g:codeactionsinprogress == 1
        return
    endif
    let actions = pyeval('getCodeActions("' . a:mode . '")')
    if(len(actions) > 0)
        call findcodeactions#setactions(a:mode, actions)
        call ctrlp#init(findcodeactions#id())
    else
        echo 'No code actions found'
    endif
endfunction

function! OmniSharp#GetIssues()
    if pumvisible()
        return get(b:, "issues", [])
    endif
	if g:serverSeenRunning == 1
        let b:issues = pyeval("getCodeIssues()")
    endif
    return get(b:, "issues", [])
endfunction

function! OmniSharp#FixIssue()
	python fixCodeIssue()
endfunction

function! OmniSharp#FindSyntaxErrors()
    if pumvisible()
        return get(b:, "syntaxerrors", [])
    endif
	if bufname('%') == ''
		return []
	endif
	if g:serverSeenRunning == 1
        let b:syntaxerrors = pyeval("findSyntaxErrors()")
    endif
    return get(b:, "syntaxerrors", [])
endfunction

" Jump to first scratch window visible in current tab, or create it.
" This is useful to accumulate results from successive operations.
" Global function that can be called from other scripts.
function! s:GoScratch()
  let done = 0
  for i in range(1, winnr('$'))
    execute i . 'wincmd w'
    if &buftype == 'nofile'
      let done = 1
      break
    endif
  endfor
  if !done
    new
    setlocal buftype=nofile bufhidden=hide noswapfile
  endif
endfunction


function! OmniSharp#TypeLookupWithoutDocumentation()
	if g:serverSeenRunning == 1
		call OmniSharp#TypeLookup('False')
	endif
endfunction

function! OmniSharp#TypeLookupWithDocumentation()
	call OmniSharp#TypeLookup('True')
endfunction

function! OmniSharp#TypeLookup(includeDocumentation)
	let type = ""

	if g:OmniSharp_typeLookupInPreview || a:includeDocumentation == 'True'
        python typeLookup("type")
		call s:GoScratch()
		python vim.current.window.height = 5
		set modifiable
		exec 'python vim.current.buffer[:] = ["' . type . '"] + """' . s:documentation . '""".splitlines()'
		set nomodifiable
		"Return to original window
		wincmd p
    else
		let line = line('.')
        let found_line_in_loc_list = 0
        "don't display type lookup if we have a syntastic error
        if exists(':SyntasticCheck')
            SyntasticSetLoclist
            for issue in getloclist(0)
                if(issue['lnum'] == line)
                    let found_line_in_loc_list = 1
                    break
                endif
            endfor
        endif
        if(found_line_in_loc_list == 0)
            python typeLookup("type")
            call OmniSharp#Echo(type)
        endif
	endif
endfunction

function! OmniSharp#Echo(message)
    echo a:message[0:&columns * &cmdheight - 2]
endfunction

function! OmniSharp#Rename()
	let renameto = inputdialog("Rename to:", expand('<cword>'))
	if renameto != ''
		call OmniSharp#RenameTo(renameto)
	endif
endfunction

function! OmniSharp#RenameTo(renameto)
	let qf_taglist = []
	python renameTo()
endfunction

function! OmniSharp#Build()
    let qf_taglist = pyeval("build()")

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	endif
endfunction

function! OmniSharp#BuildAsync()
    python buildcommand()
    let &l:makeprg=b:buildcommand
	setlocal errorformat=\ %#%f(%l\\\,%c):\ %m
	Make
endfunction

function! OmniSharp#RunTests(mode)
	wall 
	python buildcommand()

	if a:mode != 'last'
		python getTestCommand()
	endif

    let s:cmdheight=&cmdheight
    set cmdheight=5 
    let b:dispatch = b:buildcommand . " && " . s:testcommand
    if executable("sed")
        " don't match on <filename unknown>:0
        let b:dispatch .= ' | sed "s/:0//"'
    endif
    let &l:makeprg=b:dispatch
    "errorformat=msbuild,nunit stack trace
    setlocal errorformat=\ %#%f(%l\\\,%c):\ %m,%m\ in\ %#%f:%l
	Make
    let &cmdheight = s:cmdheight
endfunction

function! OmniSharp#EnableTypeHighlightingForBuffer()
	hi link CSharpUserType Type
	exec "syn keyword CSharpUserType " . s:allUserTypes
	exec "syn keyword csInterfaceDeclaration " . s:allUserInterfaces
endfunction

function! OmniSharp#EnableTypeHighlighting()

	if !OmniSharp#ServerIsRunning() || !empty(s:allUserTypes)
		return
	endif

	python lookupAllUserTypes()

	let startBuf = bufnr("%")
	" Perform highlighting for existing buffers
	bufdo if &ft == 'cs' | call OmniSharp#EnableTypeHighlightingForBuffer() | endif
	exec "b ". startBuf

	call OmniSharp#EnableTypeHighlightingForBuffer()

	augroup _omnisharp
		au!
		autocmd BufRead *.cs call OmniSharp#EnableTypeHighlightingForBuffer()
	augroup END
endfunction

function! OmniSharp#ReloadSolution()
	python getResponse("/reloadsolution")
endfunction

function! OmniSharp#UpdateBuffer()
	if OmniSharp#BufferHasChanged() == 1
        python getResponse("/updatebuffer")
    endif
endfunction

function! OmniSharp#BufferHasChanged()
	if g:serverSeenRunning == 1
        if b:changedtick != get(b:, "Omnisharp_UpdateChangeTick", -1)
            let b:Omnisharp_UpdateChangeTick = b:changedtick
            return 1
            echoerr 'wtf'
        endif
	endif
    return 0
endfunction

function! OmniSharp#CodeFormat()
	python codeFormat()
endfunction

function! OmniSharp#FixUsings()
	let qf_taglist = pyeval('fix_usings()')

	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen
	endif
endfunction

function! OmniSharp#ServerIsRunning()
	try
		python vim.command("let s:alive = '" + getResponse("/checkalivestatus", None, 0.2) + "'");
		return s:alive == 'true'
	catch
		return 0
	endtry
endfunction

function! OmniSharp#StartServerIfNotRunning()
	if !OmniSharp#ServerIsRunning()
		call OmniSharp#StartServer()
		if g:Omnisharp_stop_server==2
			au VimLeavePre * call OmniSharp#StopServer()
		endif
	endif
endfunction

function! OmniSharp#FugitiveCheck()
	if match( expand( '<afile>:p' ), "fugitive:///" ) == 0
		return 1
	else
	   return 0
	endif
endfunction

function! OmniSharp#StartServer()
	if OmniSharp#FugitiveCheck()
		return
	endif

	"get the path for the current buffer
	let folder = expand('%:p:h')
	let solutionfiles = globpath(folder, "*.sln", 1)

	while (solutionfiles == '')
		let lastfolder = folder
		"traverse up a level

		let folder = fnamemodify(folder, ':p:h:h')
		if folder == lastfolder
			break
		endif
		let solutionfiles = globpath(folder , "*.sln", 1)
	endwhile

	if solutionfiles != ''
		let array = split(solutionfiles, '\n')
		if len(array) == 1
			call OmniSharp#StartServerSolution(array[0])
		elseif g:OmniSharp_sln_list_name != ""
			echom "Started with sln: " . g:OmniSharp_sln_list_name
			call OmniSharp#StartServerSolution( g:OmniSharp_sln_list_name )
		elseif g:OmniSharp_sln_list_index > -1 && g:OmniSharp_sln_list_index < len(array)
			echom "Started with sln: " . array[g:OmniSharp_sln_list_index]
			call OmniSharp#StartServerSolution( array[g:OmniSharp_sln_list_index]  )
		else
			echom "sln: " . g:OmniSharp_sln_list_name
			let index = 1
			if g:OmniSharp_autoselect_existing_sln
				for solutionfile in array
					if index( g:OmniSharp_running_slns, solutionfile ) >= 0
						return
					endif
				endfor
			endif

			for solutionfile in array
				echo index . ' - '. solutionfile
				let index = index + 1
			endfor
			echo 'Choose a solution file'
			let option=nr2char(getchar())
			if option < '1' || option > '9'
				return
			endif
			if option > len(array)
				return
			endif

			call OmniSharp#StartServerSolution(array[option - 1])
		endif
	else
		echoerr "Did not find a solution file "
	endif
endfunction

function! OmniSharp#StartServerSolution(solutionPath)

	let g:OmniSharp_running_slns += [a:solutionPath]
	let port = exists('b:OmniSharp_port') ? b:OmniSharp_port : g:OmniSharp_port
	let command = shellescape(s:omnisharp_server,1) . ' -p ' . port . ' -s ' . shellescape(a:solutionPath, 1)
	if !has('win32') && !has('win32unix')
		let command = 'mono ' . command
	endif
	call OmniSharp#RunAsyncCommand(command)
endfunction

function! OmniSharp#RunAsyncCommand(command)
	let is_vimproc = 0
	silent! let is_vimproc = vimproc#version()
	if exists(':Make')
		call dispatch#start(a:command, {'background': 1})
	else
		if is_vimproc
			call vimproc#system_gui(substitute(a:command, '\\', '\/', 'g'))
		else
			echoerr 'Please install either vim-dispatch or vimproc plugin to use this feature'
		endif
	endif
endfunction

function! OmniSharp#AddToProject()
	python getResponse("/addtoproject")
endfunction

function! OmniSharp#AskStopServerIfRunning()
	if OmniSharp#ServerIsRunning()
		call inputsave()
		let choice = input('Do you want to stop the OmniSharp server? (Y/n): ')
		call inputrestore()
		if choice != "n"
			call OmniSharp#StopServer(1)
		endif
	endif
endfunction

function! OmniSharp#StopServer(...)
	if a:0 > 0
		let force = a:1
	else
		let force = 0
	endif

	if force || OmniSharp#ServerIsRunning()
		python getResponse("/stopserver")
	endif
endfunction

function! OmniSharp#AddReference(reference)
	if findfile(fnamemodify(a:reference, ':p')) != ''
		let a:ref = fnamemodify(a:reference, ':p')
	else
		let a:ref = a:reference
	endif
	python addReference()
endfunction

function! OmniSharp#AppendCtrlPExtensions()
	" Don't override settings made elsewhere
	if !exists("g:ctrlp_extensions")
		let g:ctrlp_extensions = []
	endif
	if !exists("g:OmniSharp_ctrlp_extensions_added")
		let g:OmniSharp_ctrlp_extensions_added = 1
		let g:ctrlp_extensions += ['findtype', 'findsymbols', 'findcodeactions']
	endif
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
