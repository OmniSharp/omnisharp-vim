let s:save_cpo = &cpo
set cpo&vim

let s:omnisharp_server = join([expand('<sfile>:p:h:h'), 'server', 'OmniSharp', 'bin', 'Debug', 'OmniSharp.exe'], '/')

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

function! OmniSharp#GotoDefinition()
	python gotoDefinition()
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
	let a:renameto = inputdialog("Rename to:")
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

function! OmniSharp#ReloadSolution()
	python getResponse("/reloadsolution")
endfunction

function! OmniSharp#CodeFormat()
	python codeFormat()
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
		echoerr "Did not find a solution file"
	endif
endfunction

function! OmniSharp#StartServerSolution(solutionPath)
	let command = shellescape(s:omnisharp_server,1) . ' -s ' . fnamemodify(a:solutionPath, ':8')
	if !has('win32')
		let command = 'mono ' . command
	endif

	let is_vimproc = 0
	silent! let is_vimproc = vimproc#version()
	if is_vimproc
		call vimproc#system_gui(substitute(command, '\\', '\/', 'g'))
	else
		call dispatch#start(command, {'background': has('win32') ? 0 : 1})
	endif
endfunction

function! OmniSharp#AddToProject()
	python getResponse("/addtoproject")
endfunction

function! OmniSharp#StopServer()
	python getResponse("/stopserver")
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
