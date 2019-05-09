let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = 1001
let s:requests = {}

function! s:Request(command, ...) abort
  let filename = OmniSharp#util#TranslatePathForServer(expand('%:p'))
  " Unique string separator which must not exist in the buffer
  let sep = matchstr(reltimestr(reltime()), '\v\.@<=\d+')
  while search(sep, 'n')
    let sep = matchstr(reltimestr(reltime()), '\v\.@<=\d+')
  endwhile
  let buffer = join(getline(1, '$'), sep)

  let body = {
  \ 'Seq': s:nextseq,
  \ 'Command': a:command,
  \ 'Type': 'Request',
  \ 'Arguments': {
  \   'Filename': filename,
  \   'Line': line('.'),
  \   'Column': col('.'),
  \   'Buffer': buffer
  \  }
  \}
  let body = substitute(json_encode(body), sep, '\\r\\n', 'g')

  let s:requests[s:nextseq] = { 'Seq': s:nextseq }
  if a:0 > 0
    let s:requests[s:nextseq].EndpointResponseHandler = a:1
  endif
  let s:nextseq += 1
  call ch_sendraw(OmniSharp#GetHost(), body . "\n")
endfunction

function! s:LocationsFromResponse(quickfixes) abort
  let locations = []
  for quickfix in a:quickfixes
    let text = get(quickfix, 'Text', get(quickfix, 'Message', ''))
    let filename = get(quickfix, 'FileName', '')
    if filename ==# ''
      let filename = expand('%:p')
    else
      let filename = OmniSharp#util#TranslatePathForClient(filename)
    endif
    let location = {
    \ 'filename': filename,
    \ 'text': text,
    \ 'lnum': quickfix.Line,
    \ 'col': quickfix.Column,
    \ 'vcol': 0
    \}
    let loglevel = get(quickfix, 'LogLevel', '')
    if loglevel !=# ''
      let location.type = loglevel ==# 'Error' ? 'E' : 'W'
      if loglevel ==# 'Hidden'
        let location.subtype = 'Style'
      endif
    endif
    call add(locations, location)
  endfor
  return locations
endfunction

function! OmniSharp#stdio#HandleResponse(channelid, message) abort
  " TODO: Log it
  try
    let res = json_decode(a:message)
  catch
    " TODO: Log it
    return
  endtry
  if !has_key(res, 'Request_seq') || !has_key(s:requests, res.Request_seq)
    return
  endif
  let req = remove(s:requests, res.Request_seq)
  if has_key(req, 'EndpointResponseHandler')
    call req.EndpointResponseHandler(res)
  endif
endfunction

function! OmniSharp#stdio#CodeCheck(Callback) abort
  call s:Request('/codecheck', function('s:CodeCheckResponseHandler', [a:Callback]))
endfunction

function! s:CodeCheckResponseHandler(Callback, response) abort
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction

function! OmniSharp#stdio#FindHighlightTypes(Callback) abort
  let bufferLines = getline(1, '$')
  call s:Request('/highlight', function('s:FindHighlightTypesResponseHandler', [a:Callback, bufferLines]))
endfunction

function! s:FindHighlightTypesResponseHandler(Callback, bufferLines, response) abort
  if !a:response.Success | return | endif
  let highlights = get(a:response.Body, 'Highlights', [])
  let identifierKinds = ['constant name', 'enum member name', 'field name',
  \ 'identifier', 'local name', 'parameter name', 'property name',
  \ 'static symbol']
  let interfaceKinds = ['interface name']
  let methodKinds = ['extension method name', 'method name']
  let typeKinds = ['class name', 'enum name', 'namespace name', 'struct name']
  let types = []
  for hl in highlights
    let lnum = hl.StartLine - 1
    if lnum >= len(a:bufferLines)
      " An error has occurred with invalid line endings - perhaps a combination
      " of unix and dos line endings?
      call a:Callback({'error': 'Invalid buffer - check line endings'})
      return
    endif
    let line = a:bufferLines[lnum]
    call add(types, {
    \ 'kind': hl['Kind'],
    \ 'name': line[hl['StartColumn'] - 1 : hl['EndColumn'] - 2]
    \})
  endfor

  let hltypes = {
  \ 'identifiers': map(filter(copy(types), 'index(identifierKinds, v:val.kind) >= 0'), 'v:val.name'),
  \ 'interfaces': map(filter(copy(types), 'index(interfaceKinds, v:val.kind) >= 0'), 'v:val.name'),
  \ 'methods': map(filter(copy(types), 'index(methodKinds, v:val.kind) >= 0'), 'v:val.name'),
  \ 'types': map(filter(copy(types), 'index(typeKinds, v:val.kind) >= 0'), 'v:val.name')
  \}

  call a:Callback(hltypes)
endfunction

function! OmniSharp#stdio#FindImplementations(Callback) abort
  call s:Request('/findimplementations', function('s:FindImplementationsResponseHandler', [a:Callback]))
endfunction

function! s:FindImplementationsResponseHandler(Callback, response) abort
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction

function! OmniSharp#stdio#FindUsages(Callback) abort
  call s:Request('/findusages', function('s:FindUsagesResponseHandler', [a:Callback]))
endfunction

function! s:FindUsagesResponseHandler(Callback, response) abort
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction

function! OmniSharp#stdio#GotoDefinition(Callback) abort
  call s:Request('/gotodefinition', function('s:GotoDefinitionResponseHandler', [a:Callback]))
endfunction

function! s:GotoDefinitionResponseHandler(Callback, response) abort
  if get(a:response.Body, 'FileName', v:null) != v:null
    call a:Callback(s:LocationsFromResponse([a:response.Body])[0])
  else
    call a:Callback(0)
  endif
endfunction

function! OmniSharp#stdio#UpdateBuffer() abort
  call s:Request('/updatebuffer')
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
