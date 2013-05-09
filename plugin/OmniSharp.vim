if exists("g:OmniSharp_loaded")
	finish
endif

let g:OmniSharp_loaded = 1

"Showmatch significantly slows down omnicomplete
"when the first match contains parentheses.
"Temporarily disable it
set noshowmatch
let s:omnisharp_path = expand('<sfile>:p:h')
"Load python/OmniSharp.py
let s:py_path = s:omnisharp_path
let s:omnisharp_server = s:omnisharp_path
python << EOF
import vim, os.path
py_path = os.path.join(vim.eval("s:omnisharp_path"), "..", "python", "OmniSharp.py")
omnisharp_server = os.path.join(vim.eval("s:omnisharp_server"), "..", "server", "OmniSharp", "bin", "Debug", "OmniSharp.exe")
vim.command("let s:py_path = '" + py_path + "'")
vim.command("let s:omnisharp_server = '" + omnisharp_server + "'")
EOF
exec "pyfile " . fnameescape(s:py_path)

"Setup variable defaults
"Default value for the server address
if !exists('g:OmniSharp_host')
	let g:OmniSharp_host='http://localhost:2000'
endif

"Don't use the preview window by default
if !exists("g:OmniSharp_typeLookupInPreview")
	let g:OmniSharp_typeLookupInPreview = 0
endif

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
	if(option < '0' || option > '9')
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
		if(folder == lastfolder)
			break
		endif
		let solutionfiles = globpath(folder , "*.sln")
	endwhile

    if (solutionfiles != '')
		let array = split(solutionfiles, '\n')
		if (len(array) == 1)
			call OmniSharp#StartServerSolution(array[0])
		else
			let index = 1
			for solutionfile in array
				echo index . ' - '. solutionfile
				let index = index + 1
			endfor
			echo 'Choose a solution file'
			let option=nr2char(getchar())
			if(option < '1' || option > '9')
				return
			endif
			if(option > len(array))
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
	call dispatch#start(command, {'background': 0})
endfunction
