if exists("g:OmniSharp_loaded")
	finish
endif

let g:OmniSharp_loaded = 1

"Load python/OmniSharp.py
let s:py_path=fnameescape(expand('<sfile>:p:h'))
python << EOF
import vim, os.path
py_path = os.path.join(vim.eval("s:py_path"), "..", "python", "OmniSharp.py")
vim.command("let s:py_path = '" + py_path + "'")
EOF
exec "pyfile " . s:py_path

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
		return {'words': words, 'refresh': ''}
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
