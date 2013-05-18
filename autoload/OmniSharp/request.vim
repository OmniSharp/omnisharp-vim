let s:save_cpo = &cpo
set cpo&vim

let s:V = vital#of('OmniSharp')
let s:Http = s:V.import('Web.Http')
let s:Json = s:V.import('Web.Json')

function! s:fixDict(dict)
  let e = {}
  let e.buffer = get(a:dict,'Buffer','')
  let e.changes = get(a:dict,'Changes',[])
  let e.codeactions = get(a:dict,'CodeActions','')
  let e.column = get(a:dict,'Column',0)
  let e.completiontext = get(a:dict,'CompletionText','')
  let e.description = get(a:dict,'Description','')
  let e.displaytext = get(a:dict,'DisplayText','')
  let e.errors = s:fixList(get(a:dict,'Errors',[]))
  let e.filename = get(a:dict,'FileName','')
  let e.line = get(a:dict,'Line',0)
  let e.locations = get(a:dict,'Locations',[])
  let e.message = get(a:dict,'Message',[])
  let e.quickfixes = s:fixList(get(a:dict,'QuickFixes',[]))
  let e.success = get(a:dict,'Success',0)
  let e.text = get(a:dict,'Text','')
  let e.type = get(a:dict,'Type','')
  let e.usages = get(a:dict,'Usages',[])
  if empty(e.usages)
    let e.usages = []
  endif
  return e
endfunction

function! s:fixList(list)
  let es = []
  for js in a:list
    if type(js) == type({})
      let es += [ s:fixDict(js) ]
    elseif type(js) == type([])
      let es += s:fixList(js)
    else
      throw string(js)
    endif
  endfor
  return es
endfunction

" http://ideone.com/KSKlZu
function! s:getResponse(endPoint, ...)
  let parameters = 0 < a:0 ? a:1 : {}
  let parameters['line'] = line(".")
  let parameters['column'] = col(".")
  let parameters['buffer'] = join(getline(1,'$'),"\r\n")
  let parameters['filename'] = substitute(expand('%:p'), '\\','\/','g')
  let res = s:Http.post(g:OmniSharp_host . a:endPoint, parameters)
  let content = empty(res.content) ? "{}" : res.content
  try
    return s:fixList([ s:Json.decode(content) ])
  catch /.*/
    echoerr v:exception
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

function! OmniSharp#request#autocomplete(parameters)
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
