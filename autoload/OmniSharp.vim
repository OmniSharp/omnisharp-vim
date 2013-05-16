let s:save_cpo = &cpo
set cpo&vim

let s:omnisharp_server = join([expand('<sfile>:p:h:h'), 'server', 'OmniSharp', 'bin', 'Debug', 'OmniSharp.exe'], '/')

let s:V = vital#of('OmniSharp')
let s:Http = s:V.import('Web.Http')
let s:Json = s:V.import('Web.Json')

function! s:build()
	let response = s:getResponse('/build')
	if type(response) == type({}) && get(response,"Success",0)
		echo "Build succeeded"
		let quickfixes = get(response,'QuickFixes',[])
		return s:populateQuickFix(quickfixes)
	else
		echo "Build failed"
		return []
	endif
endfunction

function! s:findImplementations()
	let response = s:getResponse('/findimplementations')
	let ret = []
	if ! empty(response)
		let locations = get(response,'Locations',[])

		if len(locations) == 1
			let usage = get(locations,0,'')
			let filename = get(usage,'FileName','')
			if !empty(filename)
				if fnamemodify(filename,':p') != expand('%:p')
					execute printf('e %s', filename)
				endif
				" row is 1 based, column is 0 based
				call setpos('.',[ 0, usage['Line'], usage['Column'] - 1, 0])
			endif
		else
			for usage in locations
				let usage["FileName"] = fnamemodify(get(usage,"FileName",''),':.')
				let ret += [ {
							\ 'filename': get(usage,'FileName',''),
							\ 'lnum': get(usage,'Line',''),
							\ 'col': get(usage,'Column',''),
							\ } ]
			endfor
		endif
	endif
	return ret
endfunction

function! s:findSyntaxErrors()
	let response = s:getResponse('/syntaxerrors')
	let ret = []
	if ! empty(response)
		for err in get(response,'Errors',[])
			let ret += [ {
						\ 'filename': get(err,'FileName',''),
						\ 'text': get(err,'Message',''),
						\ 'lnum': get(err,'Line',''),
						\ 'col': get(err,'Column',''),
						\ } ]
		endfor
	endif
	return ret
endfunction

function! s:findUsages()
	let response = s:getResponse('/findusages')
	let ret = []
	if ! empty(response)
		let usages = get(response,'Usages',[])
		let ret = s:populateQuickFix(usages)
	endif
	return ret
endfunction

function! s:getCodeActions()
	let response = s:getResponse('/getcodeactions')
	if ! empty(response)
		let index = 1
		let actions = get(response,'CodeActions','')
		for action in actions
			echo printf("%d :  %s", index, action)
			if 0 < len(actions)
				return 1
			endif
			let index += 1
		endfor
	endif
	return 0
endfunction

function! s:getCompletions(column, partialWord, textBuffer)
	" All of these functions take vim variable names as parameters
	let parameters = {}
	let parameters['column'] = a:column
	let parameters['wordToComplete'] = a:partialWord
	let parameters['buffer'] = join(a:textBuffer,"\r\n")
	let completions = s:getResponse('/autocomplete', parameters)
	let words = []
	for completion in completions
		let words += [ {
					\ 'word' : get(completion,'CompletionText',''),
					\ 'abbr' : get(completion,'DisplayText',''),
					\ 'info': get(completion,'Description',''),
					\ 'icase' : 1,
					\ 'dup' : 1,
					\ } ]
	endfor
	return words
endfunction

function! s:populateQuickFix(quickfixes)
	let ret = []
	if ! empty(a:quickfixes)
		for quickfix in a:quickfixes
			let quickfix["FileName"] = fnamemodify(get(quickfix,"FileName",''),":.")
			let ret += [ {
						\ 'filename': get(quickfix,'FileName',''),
						\ 'text': get(quickfix,'Text',''),
						\ 'lnum': get(quickfix,'Line',''),
						\ 'col': get(quickfix,'Column','')
						\ } ]
		endfor
	endif
	return ret
endfunction

function! s:runCodeAction(option)
	let parameters = {}
	let parameters['codeaction'] = a:option
	let response = s:getResponse('/runcodeaction', parameters)
	let text = get(response,'Text','')
	if empty(text)
		return
	endif
	let lines = split(text,"\n")
	let pos = getpos('.')
	call s:setBuffer(lines)
	call setpos('.',pos)
endfunction

function! s:setBuffer(buffer)
	let lines = split(a:buffer,"\n")
	" TODO: fix python code to vim script code
	" lines = [line.encode('utf-8') for line in lines]
	call s:setCurrBuffer(lines)
endfunction

function! s:typeLookup()
	let response = s:getResponse('/typelookup')
	if ! empty(response)
		return get(response,'Type','')
	endif
	return ''
endfunction

function! s:getResponse(endPoint, ...)
	let parameters = 0 < a:0 ? a:1 : {}
	let parameters['line'] = line(".")
	let parameters['column'] = col(".")
	let parameters['buffer'] = join(getline(1,'$'),"\r\n")
	if exists("+shellslash") && &shellslash
		let parameters['filename'] = substitute(fnamemodify(expand('%'),':p'),'/','\\','g')
	else
		let parameters['filename'] = fnamemodify(expand('%'),':p')
	endif

	let target = g:OmniSharp_host . a:endPoint
	let res = s:Http.post(target,parameters)
	try
		return s:Json.decode(res.content)
	catch
		return []
	endtry
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
		let words = s:getCompletions(s:column, a:base,s:textBuffer)
		if len(words) == 0
			return -3
		endif
		return words
	endif
endfunction

function! OmniSharp#FindUsages()
	let qf_taglist = s:findUsages()

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	else
		echo "No usages found"
	endif
endfunction

function! OmniSharp#FindImplementations()
	let qf_taglist = s:findImplementations()

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 1
		call setqflist(qf_taglist)
		copen 4
	endif
endfunction

function! OmniSharp#GotoDefinition()
	let response = s:getResponse('/gotodefinition')
	if ! empty(response)
		let filename = get(response,'FileName','')
		if ! empty(filename)
			if fnamemodify(filename,':p') != expand('%:p')
				execute printf('e %s', filename)
			endif
			" row is 1 based, column is 0 based
			call setpos('.',[ 0, response['Line'], response['Column'] - 1, 0])
		endif
	endif
endfunction

function! OmniSharp#GetCodeActions()
	let actions = s:getCodeActions()
	if actions
		return 0
	endif

	let option = nr2char(getchar())
	if option < '0' || option > '9'
		return 1
	endif

	call s:runCodeAction(option)
endfunction

function! OmniSharp#FindSyntaxErrors()
	if bufname('%') == ''
		return
	endif
	let qf_taglist = s:findSyntaxErrors()

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	else
		cclose
	endif
endfunction

function! OmniSharp#TypeLookup()
	let type = s:typeLookup()

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
	let parameters = {}
	let parameters['renameto'] = a:renameto
	let response = s:getResponse('/rename', parameters)
	let currentBuffer = expand('%')
	let pos = getpos('.')
	for change in get(response,'Changes',[])
		let lines = split(get(change,'Buffer',''),"\n")
		" TODO
		" lines = [line.encode('utf-8') for line in lines]
		let filename = get(change,'FileName','')
		if ! empty(filename)
			execute 'argadd ' . filename
			for buf in filter(range(1, bufnr("$")),"bufexists(v:val) && buflisted(v:val)")
				if bufname(bnum) == filename
					execute 'b ' . filename
					silent % delete _
					silent put =lines
					silent 1 delete _
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
	let qf_taglist = s:build()

	" Place the tags in the quickfix window, if possible
	if len(qf_taglist) > 0
		call setqflist(qf_taglist)
		copen 4
	endif
endfunction

function! OmniSharp#ReloadSolution()
	call s:getResponse("/reloadsolution")
endfunction

function! OmniSharp#CodeFormat()
	let response = s:getResponse('/codeformat')
	if ! empty(response)
		call s:setBuffer(get(response,"Buffer",''))
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
	call dispatch#start(command, {'background': has('win32') ? 0 : 1})
endfunction

function! OmniSharp#AddToProject()
	call s:getResponse("/addtoproject")
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
