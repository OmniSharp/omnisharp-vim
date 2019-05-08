let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = 1001
let s:requests = {}

function! s:Request(command, EndpointResponseHandler) abort
  let filename = OmniSharp#util#TranslatePathForServer(expand('%:p'))
  let buffer = join(getline(1, '$'), '\r\n')

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
  let body = substitute(json_encode(body), '\\\\r\\\\n', '\\r\\n', 'g')

  let s:requests[s:nextseq] = a:EndpointResponseHandler
  let s:nextseq += 1
  call ch_sendraw(OmniSharp#GetHost(), body . "\n")
endfunction

function! s:QuickFixesFromResponse(response) abort
  let text = get(a:response, 'Text', get(a:response, 'Message', ''))
  let filename = get(a:response.Body, 'FileName', '')
  if filename ==# ''
    let filename = expand('%:p')
  else
    let filename = OmniSharp#util#TranslatePathForClient(filename)
  endif
  let item = {
  \ 'filename': filename,
  \ 'text': text,
  \ 'lnum': a:response.Body.Line,
  \ 'col': a:response.Body.Column,
  \ 'vcol': 0
  \}
  let loglevel = get(a:response, 'LogLevel', '')
  if loglevel !=# ''
    let item.type = loglevel ==# 'Error' ? 'E' : 'W'
    if loglevel ==# 'Hidden'
      let item.subtype = 'Style'
    endif
  endif
  return item
endfunction

function! OmniSharp#stdio#HandleResponse(channelid, message) abort
  " TODO: Log it
  try
    let response = json_decode(a:message)
  catch
    " TODO: Log it
    return
  endtry
  if !has_key(response, 'Request_seq') || !has_key(s:requests, response.Request_seq)
    return
  endif
  let EndPointResponseHandler = s:requests[response.Request_seq]
  call remove(s:requests, response.Request_seq)
  call EndPointResponseHandler(response)
endfunction

function! OmniSharp#stdio#GotoDefinition(Callback) abort
  call s:Request('gotodefinition', function('s:GotoDefinitionResponseHandler', [a:Callback]))
endfunction

function! s:GotoDefinitionResponseHandler(Callback, response) abort
  call a:Callback(s:QuickFixesFromResponse(a:response))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
