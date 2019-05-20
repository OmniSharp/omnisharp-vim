let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = 1001
let s:requests = {}

let s:logfile = expand('<sfile>:p:h:h:h') . '/log/stdio.log'
function! s:Log(message) abort
  " Consider adding flag 's', to unsure the file is always flushed to disk
  call writefile([a:message], s:logfile, 'a')
endfunction

function! s:Request(command, opts) abort
  let job = OmniSharp#GetHost().job
  if type(job) != type({}) || !has_key(job, 'job_id') || !job.loaded
    return 0
  endif
  let job_id = job.job_id
  call s:Log(job_id . '  Request: ' . a:command)
  if has_key(a:opts, 'UsePreviousPosition')
    let [bufnum, lnum, cnum] = s:lastPosition
  elseif has_key(a:opts, 'BufNum') && a:opts.BufNum != bufnr('%')
    let bufnum = a:opts.BufNum
    let lnum = 1
    let cnum = 1
  else
    let bufnum = bufnr('%')
    let lnum = line('.')
    let cnum = col('.')
  endif
  if has_key(a:opts, 'SavePosition')
    let s:lastPosition = [bufnum, lnum, cnum]
  endif
  let filename = OmniSharp#util#TranslatePathForServer(
  \ fnamemodify(bufname(bufnum), ':p'))
  let lines = getbufline(bufnum, 1, '$')
  let tmp = join(lines, '')
  " Unique string separator which must not exist in the buffer
  let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
  while stridx(tmp, sep) >= 0
    let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
  endwhile
  let buffer = join(lines, sep)

  let body = {
  \ 'Seq': s:nextseq,
  \ 'Command': a:command,
  \ 'Type': 'Request',
  \ 'Arguments': {
  \   'Filename': filename,
  \   'Line': lnum,
  \   'Column': cnum,
  \   'Buffer': buffer
  \ }
  \}
  if has_key(a:opts, 'Parameters')
    call extend(body.Arguments, a:opts.Parameters, 'force')
  endif
  let body = substitute(json_encode(body), sep, '\\r\\n', 'g')

  let s:requests[s:nextseq] = { 'Seq': s:nextseq }
  if has_key(a:opts, 'ResponseHandler')
    let s:requests[s:nextseq].ResponseHandler = a:opts.ResponseHandler
  endif
  let s:nextseq += 1
  call s:Log(body)
  if has('nvim')
    call chansend(job_id, body . "\n")
  else
    call ch_sendraw(job_id, body . "\n")
  endif
  return 1
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
        let location.subtype = 'style'
      endif
    endif
    call add(locations, location)
  endfor
  return locations
endfunction

function! s:SetBuffer(text) abort
  if a:text == v:null | return 0 | endif
  let pos = getpos('.')
  let lines = split(a:text, '\r\?\n')
  if len(lines) < line('$')
    call deletebufline('%', len(lines) + 1, '$')
  endif
  call setline(1, lines)
  let pos[1] = min([pos[1], line('$')])
  call setpos('.', pos)
  return 1
endfunction

function! OmniSharp#stdio#HandleResponse(job, message) abort
  call s:Log(a:job.job_id . '  ' . a:message)
  try
    let res = json_decode(a:message)
  catch
    call s:Log(a:job.job_id . '  JSON error: ' . v:exception)
    return
  endtry
  if get(res, 'Type', '') ==# 'event'
    if !a:job.loaded && has_key(res, 'Body') && type(res.Body) == type({})
      let message = get(res.Body, 'Message', '')
      if message ==# 'Configuration finished.'
        call OmniSharp#proc#JobLoaded(a:job.job_id)
      endif
    endif
    return
  endif
  if !has_key(res, 'Request_seq') || !has_key(s:requests, res.Request_seq)
    return
  endif
  let req = remove(s:requests, res.Request_seq)
  if has_key(req, 'ResponseHandler')
    call req.ResponseHandler(res)
  endif
endfunction

function! OmniSharp#stdio#CodeCheck(opts, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeCheckRH', [a:Callback])
  \}
  call extend(opts, a:opts, 'force')
  call s:Request('/codecheck', opts)
endfunction

function! s:CodeCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction

function! OmniSharp#stdio#CodeFormat() abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeFormatRH'),
  \ 'ExpandTab': &expandtab
  \}
  call s:Request('/codeformat', opts)
endfunction

function! s:CodeFormatRH(response) abort
  if !a:response.Success | return | endif
  call s:SetBuffer(a:response.Body.Buffer)
endfunction

function! OmniSharp#stdio#FindHighlightTypes(Callback) abort
  let bufferLines = getline(1, '$')
  let opts = {
  \ 'ResponseHandler': function('s:FindHighlightTypesRH', [a:Callback, bufferLines])
  \}
  call s:Request('/highlight', opts)
endfunction

function! s:FindHighlightTypesRH(Callback, bufferLines, response) abort
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
  let opts = {
  \ 'ResponseHandler': function('s:FindImplementationsRH', [a:Callback])
  \}
  call s:Request('/findimplementations', opts)
endfunction

function! s:FindImplementationsRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction

function! OmniSharp#stdio#FindMembers(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FindMembersRH', [a:Callback])
  \}
  call s:Request('/currentfilemembersasflat', opts)
endfunction

function! s:FindMembersRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:LocationsFromResponse(a:response.Body))
endfunction

function! OmniSharp#stdio#FindSymbol(filter, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FindSymbolRH', [a:Callback]),
  \ 'Parameters': { 'Filter': a:filter }
  \}
  call s:Request('/findsymbols', opts)
endfunction

function! s:FindSymbolRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction

function! OmniSharp#stdio#FindUsages(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FindUsagesRH', [a:Callback])
  \}
  call s:Request('/findusages', opts)
endfunction

function! s:FindUsagesRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction

function! OmniSharp#stdio#FixUsings(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FixUsingsRH', [a:Callback])
  \}
  call s:Request('/fixusings', opts)
endfunction

function! s:FixUsingsRH(Callback, response) abort
  if !a:response.Success | return | endif
  call s:SetBuffer(a:response.Body.Buffer)
  let locations = s:LocationsFromResponse(a:response.Body.AmbiguousResults)
  call a:Callback(locations)
endfunction

function! OmniSharp#stdio#GetCodeActions(mode, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:GetCodeActionsRH', [a:Callback]),
  \ 'SavePosition': 1
  \}
  if a:mode ==# 'visual'
    let start = getpos("'<")
    let end = getpos("'>")
    let s:codeActionParameters = {
    \ 'Selection': {
    \   'Start': {
    \     'Line': start[1],
    \     'Column': start[2]
    \   },
    \   'End': {
    \     'Line': end[1],
    \     'Column': end[2]
    \   }
    \ }
    \}
    let opts.Parameters = s:codeActionParameters
  endif
  call s:Request('/v2/getcodeactions', opts)
endfunction

function! s:GetCodeActionsRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(a:response.Body.CodeActions)
endfunction

function! OmniSharp#stdio#GetCompletions(partial, Callback) abort
  let want_doc = g:omnicomplete_fetch_full_documentation ? 'true' : 'false'
  let want_snippet = g:OmniSharp_want_snippet ? 'true' : 'false'
  let parameters = {
  \ 'WordToComplete': a:partial,
  \ 'WantDocumentationForEveryCompletionResult': want_doc,
  \ 'WantSnippet': want_snippet,
  \ 'WantMethodHeader': 'true',
  \ 'WantReturnType': 'true'
  \}
  let opts = {
  \ 'ResponseHandler': function('s:GetCompletionsRH', [a:Callback]),
  \ 'Parameters': parameters
  \}
  call s:Request('/autocomplete', opts)
endfunction

function! s:GetCompletionsRH(Callback, response) abort
  if !a:response.Success | return | endif
  let completions = []
  for cmp in a:response.Body
    if g:OmniSharp_want_snippet
      let word = cmp.MethodHeader != v:null ? cmp.MethodHeader : cmp.CompletionText
      let menu = cmp.ReturnType != v:null ? cmp.ReturnType : cmp.DisplayText
    else
      let word = cmp.CompletionText != v:null ? cmp.CompletionText : cmp.MethodHeader
      let menu = (cmp.ReturnType != v:null ? cmp.ReturnType . ' ' : '') .
      \ ' ' . (cmp.DisplayText != v:null ? cmp.DisplayText : cmp.MethodHeader)
    endif
    call add(completions, {
    \ 'snip': get(cmp, 'Snippet', ''),
    \ 'word': word,
    \ 'menu': menu,
    \ 'info': substitute(get(cmp, 'Description', ' '), '\r\n', '\n', 'g'),
    \ 'icase': 1,
    \ 'dup': 1
    \})
  endfor
  call a:Callback(completions)
endfunction

function! OmniSharp#stdio#GotoDefinition(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:GotoDefinitionRH', [a:Callback])
  \}
  call s:Request('/gotodefinition', opts)
endfunction

function! s:GotoDefinitionRH(Callback, response) abort
  if !a:response.Success | return | endif
  if get(a:response.Body, 'FileName', v:null) != v:null
    call a:Callback(s:LocationsFromResponse([a:response.Body])[0])
  else
    call a:Callback(0)
  endif
endfunction

function! OmniSharp#stdio#NavigateDown() abort
  let opts = {
  \ 'ResponseHandler': function('s:NavigateRH')
  \}
  call s:Request('/navigatedown', opts)
endfunction

function! OmniSharp#stdio#NavigateUp() abort
  let opts = {
  \ 'ResponseHandler': function('s:NavigateRH')
  \}
  call s:Request('/navigateup', opts)
endfunction

function! s:NavigateRH(response) abort
  if !a:response.Success | return | endif
  normal! m'
  call cursor(a:response.Body.Line, a:response.Body.Column)
endfunction

function! OmniSharp#stdio#RenameTo(renameto) abort
  let opts = {
  \ 'ResponseHandler': function('s:PerformChangesRH'),
  \ 'Parameters': {
  \   'RenameTo': a:renameto
  \ }
  \}
  call s:Request('/rename', opts)
endfunction

function! OmniSharp#stdio#RunCodeAction(action) abort
  let opts = {
  \ 'ResponseHandler': function('s:PerformChangesRH'),
  \ 'Parameters': {
  \   'Identifier': a:action.Identifier
  \ },
  \ 'UsePreviousPosition': 1
  \}
  if exists('s:codeActionParameters')
    call extend(opts.Parameters, s:codeActionParameters, 'force')
  endif
  call s:Request('/v2/runcodeaction', opts)
endfunction

function! s:PerformChangesRH(response) abort
  if !a:response.Success | return | endif
  let changes = get(a:response.Body, 'Changes', [])
  if len(changes) == 0
    echo 'No action taken'
    return
  endif
  let bufname = bufname('%')
  let bufnum = bufnr('%')
  let pos = getpos('.')
  let hidden_bak = &hidden | set hidden
  for change in changes
    call OmniSharp#JumpToLocation({
    \ 'filename': OmniSharp#util#TranslatePathForClient(change.FileName),
    \}, 1)
    if !s:SetBuffer(get(change, 'Buffer', v:null))
      for filechange in get(change, 'Changes', [])
        call s:SetBuffer(get(filechange, 'NewText', v:null))
      endfor
    endif
    if bufnr('%') != bufnum
      silent write | silent edit
    endif
    call OmniSharp#JumpToLocation({
    \ 'filename': bufname,
    \ 'lnum': pos[1],
    \ 'col': pos[2]
    \}, 1)
    let &hidden = hidden_bak
  endfor
endfunction

function! OmniSharp#stdio#SignatureHelp(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:SignatureHelpRH', [a:Callback])
  \}
  call s:Request('/signaturehelp', opts)
endfunction

function! s:SignatureHelpRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(a:response.Body)
endfunction

function! OmniSharp#stdio#TypeLookup(includeDocumentation, Callback) abort
  let includeDocumentation = a:includeDocumentation ? 'true' : 'false'
  let opts = {
  \ 'ResponseHandler': function('s:TypeLookupRH', [a:Callback]),
  \ 'Parameters': { 'IncludeDocumentation': includeDocumentation}
  \}
  call s:Request('/typelookup', opts)
endfunction

function! s:TypeLookupRH(Callback, response) abort
  if !a:response.Success
    call a:Callback({ 'type': '', 'doc': '' })
  endif
  let body = a:response.Body
  call a:Callback({
  \ 'type': body.Type != v:null ? body.Type : '',
  \ 'doc': body.Documentation != v:null ? body.Documentation : ''
  \})
endfunction

function! OmniSharp#stdio#UpdateBuffer() abort
  call s:Request('/updatebuffer', {})
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
