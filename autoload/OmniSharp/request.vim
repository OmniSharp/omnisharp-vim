let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('OmniSharp')
let s:Http = s:V.import('Web.Http')
let s:Json = s:V.import('Web.Json')

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

function! OmniSharp#request#findimplementations()
	return s:getResponse('/findimplementations')
endfunction

function! OmniSharp#request#build()
	return s:getResponse('/build')
endfunction

function! OmniSharp#request#getcodeactions()
	return s:getResponse('/getcodeactions')
endfunction

function! OmniSharp#request#getcodeactions(parameters)
	return s:getResponse('/autocomplete', a:parameters)
endfunction

function! OmniSharp#request#runcodeaction(parameters)
	return s:getResponse('/runcodeaction', a:parameters)
endfunction

function! OmniSharp#request#typelookup()
	return s:getResponse('/typelookup')
endfunction

function! OmniSharp#request#syntaxerrors()
	return s:getResponse('/syntaxerrors')
endfunction

function! OmniSharp#request#findusages()
	return s:getResponse('/findusages')
endfunction

function! OmniSharp#request#gotodefinition()
	return s:getResponse('/gotodefinition')
endfunction

function! OmniSharp#request#gotodefinition()
	return s:getResponse('/gotodefinition')
endfunction

function! OmniSharp#request#rename(parameters)
	return s:getResponse('/rename', a:parameters)
endfunction

function! OmniSharp#request#reloadsolution()
	return s:getResponse('/reloadsolution')
endfunction

function! OmniSharp#request#codeformat()
	return s:getResponse('/codeformat')
endfunction

function! OmniSharp#request#addtoproject()
	return s:getResponse('/addtoproject')
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
