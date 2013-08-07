let s:save_cpo = &cpo
set cpo&vim

let s:omnisharp_server = join([expand('<sfile>:p:h:h'), 'server', 'OmniSharp', 'bin', 'Debug', 'OmniSharp.exe'], '/')
let s:allUserTypes = ''
let s:allUserInterfaces = ''

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
		let words=[]
		python getCompletions("words", "s:column", "a:base")
		if len(words) == 0
			return -3
		endif
		return words
	endif
endfunction

function! OmniSharp#FindUsages()
	let qf_taglist = []
	python findUsages("qf_taglist")

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	else
		echo "No usages found"
	endif
endfunction

function! OmniSharp#FindImplementations()
	let qf_taglist = []
	python findImplementations("qf_taglist")

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 1
		call setqflist(qf_taglist)
		copen 4
	endif
endfunction

function! OmniSharp#FindMembers()
	let qf_taglist = []
	python findMembers("qf_taglist")

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
	if a:filename != bufname('%')
		exec 'e ' . a:filename
	endif
	"row is 1 based, column is 0 based
	call cursor(a:line, a:column)
endfunction

function! OmniSharp#GetCodeActions()
	let actions = []
	python actions = getCodeActions()
	python if actions == False: vim.command("return 0")

	let option=nr2char(getchar())
	if option < '0' || option > '9'
		return 1
	endif

	python runCodeAction("option")
endfunction

function! OmniSharp#FindSyntaxErrors()
	if bufname('%') == ''
		return
	endif
	let qf_taglist = []
	python findSyntaxErrors("qf_taglist")

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	else
		cclose
	endif
endfunction

function! OmniSharp#TypeLookup()
	let type = ""
	python typeLookup("type")

	if g:OmniSharp_typeLookupInPreview
		"Try to go to preview window
		silent! wincmd P
		if !&previewwindow
			"If couldn't goto the preview window, then there is no open preview
			"window, so make one
			pedit!
			wincmd P
			python vim.current.window.height = 3
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
		exec "python vim.current.buffer[:] = ['" . type . "']"
		set nomodifiable
		"Return to original window
		wincmd p
	else
		echo type
	endif
endfunction

function! OmniSharp#Rename()
	let a:renameto = inputdialog("Rename to:", expand('<cword>'))
	if a:renameto != ''
		call OmniSharp#RenameTo(a:renameto)
	endif
endfunction

function! OmniSharp#RenameTo(renameto)
	let qf_taglist = []
	python renameTo(renameTo)
endfunction

function! OmniSharp#Build()
	let qf_taglist = []
	python build("qf_taglist")

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	endif
endfunction

function! OmniSharp#BuildAsync()
	python buildcommand()
	setlocal errorformat=\ %#%f(%l\\\,%c):\ %m
	let &l:makeprg=b:buildcommand
	Make
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

function! OmniSharp#CodeFormat()
	python codeFormat()
endfunction

function! OmniSharp#ServerIsRunning()
	let port = matchstr(g:OmniSharp_host,'[0-9]\+$')
	if has('win32') || has('win32unix')
		let lockfilename = fnamemodify(s:omnisharp_server, ':p:h') . '/lockfile-' . port
		" If lockfile is present, and locked (and thus not readable)
		" the server is running
		return glob(lockfilename) != "" && !filereadable(lockfilename)
	else
		let cmd='ps ax | grep "OmniSharp.exe -p ' . port . '" | grep -v "grep" | wc -l | tr -d " "'
		let isrunning=system(cmd)
		return isrunning > 0
	endif
endfunction

function! OmniSharp#StartServerIfNotRunning()
	if !OmniSharp#ServerIsRunning()
		call OmniSharp#StartServer()
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
	let command = shellescape(s:omnisharp_server,1) . ' -p ' . port . ' -s ' . fnamemodify(a:solutionPath, ':8')
	if !has('win32') && !has('win32unix')
		let command = 'mono ' . command
	endif
	call OmniSharp#RunAsyncCommand(command)
endfunction

function! OmniSharp#RunAsyncCommand(command)
	let is_vimproc = 0
	silent! let is_vimproc = vimproc#version()
	if is_vimproc
		call vimproc#system_gui(substitute(a:command, '\\', '\/', 'g'))
	else
		if exists(':Make')
			call dispatch#start(a:command, {'background': 1})
		else
			echoerr 'Please install vim-dispatch or vimproc plugin to use this feature'
		endif
	endif
endfunction

function! OmniSharp#AddToProject()
	python getResponse("/addtoproject")
endfunction

function! OmniSharp#AskStopServerIfNotRunning()
	if OmniSharp#ServerIsRunning()
		call inputsave()
		let choice = input('Do you want to stop the OmniSharp server? (Y/n): ')
		call inputrestore()
		if choice != "n"
			call OmniSharp#StopServer()
		endif
	endif
endfunction

function! OmniSharp#StopServer()
	python getResponse("/stopserver")
endfunction

function! OmniSharp#AddReference(reference)
	if findfile(fnamemodify(a:reference, ':p')) != ''
		let a:ref = fnamemodify(a:reference, ':p')
	else
		let a:ref = a:reference
	endif
	python addReference()
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
