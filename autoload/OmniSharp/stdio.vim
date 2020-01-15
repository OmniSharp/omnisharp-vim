let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = get(s:, 'nextseq', 1001)
let s:requests = get(s:, 'requests', {})
let s:pendingRequests = get(s:, 'pendingRequests', {})

function! s:HandleServerEvent(job, res) abort
  if has_key(a:res, 'Body') && type(a:res.Body) == type({})
    if !a:job.loaded

      " Listen for server-loaded events
      "-------------------------------------------------------------------------
      if g:OmniSharp_server_stdio_quickload
        " Quick load: Mark server as loaded as soon as configuration is finished
        let message = get(a:res.Body, 'Message', '')
        if message ==# 'Configuration finished.'
          let a:job.loaded = 1
          silent doautocmd <nomodeline> User OmniSharpReady
          call s:ReplayRequests()
        endif
      else
        " Complete load: Wait for all projects to be loaded before marking
        " server as loaded
        if !has_key(a:job, 'loading_timeout')
          " Create a timeout to mark a job as loaded after 30 seconds despite
          " not receiving the expected server events.
          let a:job.loading_timeout = timer_start(
          \ g:OmniSharp_server_loading_timeout * 1000,
          \ function('s:ServerLoadTimeout', [a:job]))
        endif
        if !has_key(a:job, 'loading')
          let a:job.loading = []
        endif
        let name = get(a:res.Body, 'Name', '')
        let message = get(a:res.Body, 'Message', '')
        if name ==# 'OmniSharp.MSBuild.ProjectManager'
          let project = matchstr(message, '''\zs.*\ze''')
          if message =~# '^Queue project'
            call add(a:job.loading, project)
          endif
          if message =~# '^Successfully loaded project'
            call filter(a:job.loading, {idx,val -> val !=# project})
            if len(a:job.loading) == 0
              if g:OmniSharp_server_display_loading
                echomsg 'Loaded server for ' . a:job.sln_or_dir
              endif
              let a:job.loaded = 1
              silent doautocmd <nomodeline> User OmniSharpReady

              " TODO: Remove this delay once we have better information about when the
              " server is completely initialised:
              " https://github.com/OmniSharp/omnisharp-roslyn/issues/1521
              call timer_start(1000, function('s:ReplayRequests'))
              " call s:ReplayRequests()

              unlet a:job.loading
              call timer_stop(a:job.loading_timeout)
              unlet a:job.loading_timeout
            endif
          endif
        endif
      endif

    else

      " Server is loaded, listen for diagnostics
      "-------------------------------------------------------------------------
      if get(a:res, 'Event', '') ==# 'Diagnostic'
        if has_key(g:, 'OmniSharp_ale_diagnostics_requested')
          for result in get(a:res.Body, 'Results', [])
            let fname = OmniSharp#util#TranslatePathForClient(result.FileName)
            let bufinfo = getbufinfo(fname)
            if len(bufinfo) == 0 || !has_key(bufinfo[0], 'bufnr')
              continue
            endif
            let bufnum = bufinfo[0].bufnr
            call ale#other_source#StartChecking(bufnum, 'OmniSharp')
            let opts = { 'BufNum': bufnum }
            let quickfixes = s:LocationsFromResponse(result.QuickFixes)
            call ale#sources#OmniSharp#ProcessResults(opts, quickfixes)
          endfor
        endif
      elseif get(a:res, 'Event', '') ==# 'TestMessage'
        " Diagnostics received while running tests
        let lines = split(a:res.Body.Message, '\n')
        for line in lines
          if get(a:res.Body, 'MessageLevel', '') ==# 'error'
            echohl WarningMsg | echomsg line | echohl None
          elseif g:OmniSharp_runtests_echo_output
            echomsg line
          endif
        endfor
      endif

    endif
  endif
endfunction

function! s:ServerLoadTimeout(job, timer) abort
  if g:OmniSharp_server_display_loading
    echomsg printf('Server load notification for %s not received after %d seconds - continuing.',
    \ a:job.sln_or_dir, g:OmniSharp_server_loading_timeout)
  endif
  let a:job.loaded = 1
  unlet a:job.loading
  unlet a:job.loading_timeout
endfunction

let s:logfile = expand('<sfile>:p:h:h:h') . '/log/stdio.log'
function! s:Log(message, loglevel) abort
  let logit = 0
  if g:OmniSharp_loglevel ==? 'debug'
    " Log everything
    let logit = 1
  elseif g:OmniSharp_loglevel ==? 'info'
    let logit = a:loglevel ==# 'info'
  else
    " g:OmniSharp_loglevel ==? 'none'
  endif
  if logit
    call writefile([a:message], s:logfile, 'a')
  endif
endfunction

function! s:Request(command, opts) abort
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
  let metadata_filename = get(b:, 'OmniSharp_metadata_filename', v:null)
  let is_metadata = type(metadata_filename) == type('')
  if is_metadata
    let filename = metadata_filename
    let send_buffer = 0
  else
    let filename = OmniSharp#util#TranslatePathForServer(
    \ fnamemodify(bufname(bufnum), ':p'))
    let send_buffer = get(a:opts, 'SendBuffer', 1)
  endif
  let lines = getbufline(bufnum, 1, '$')
  let tmp = join(lines, '')
  " Unique string separator which must not exist in the buffer
  let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
  while stridx(tmp, sep) >= 0
    let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
  endwhile
  let buffer = join(lines, sep)

  let body = {
  \ 'Arguments': {
  \   'FileName': filename,
  \   'Line': lnum,
  \   'Column': cnum,
  \ }
  \}

  if send_buffer
    let body.Arguments.Buffer = buffer
  endif
  return s:RawRequest(body, a:command, a:opts, sep)
endfunction

function! s:RawRequest(body, command, opts, ...) abort
  let sep = a:0 ? a:1 : ''

  let job = OmniSharp#GetHost().job
  if type(job) != type({}) || !has_key(job, 'job_id') || !job.loaded
    if has_key(a:opts, 'ReplayOnLoad') && !has_key(s:pendingRequests, a:command)
      " This request should be replayed when the server is fully loaded
      let s:pendingRequests[a:command] = a:opts
    endif
    return 0
  endif
  let job_id = job.job_id
  call s:Log(job_id . '  Request: ' . a:command, 'debug')

  let a:body['Command'] = a:command
  let a:body['Seq'] = s:nextseq
  let a:body['Type'] = 'request'
  if has_key(a:opts, 'Parameters')
    call extend(a:body.Arguments, a:opts.Parameters, 'force')
  endif
  if sep !=# ''
    let encodedBody = substitute(json_encode(a:body), sep, '\\r\\n', 'g')
  else
    let encodedBody = json_encode(a:body)
  endif

  let s:requests[s:nextseq] = { 'Seq': s:nextseq }
  if has_key(a:opts, 'ResponseHandler')
    let s:requests[s:nextseq].ResponseHandler = a:opts.ResponseHandler
  endif
  let s:nextseq += 1
  call s:Log(encodedBody, 'debug')
  if has('nvim')
    call chansend(job_id, encodedBody . "\n")
  else
    call ch_sendraw(job_id, encodedBody . "\n")
  endif
  return 1
endfunction

function! s:ReplayRequests(...) abort
  for key in keys(s:pendingRequests)
    call s:Request(key, s:pendingRequests[key])
    unlet s:pendingRequests[key]
  endfor
endfunction

" Call a list of async functions in parallel, and wait for them all to complete
" before calling the OnAllComplete function.
function! s:AwaitParallel(Funcs, OnAllComplete) abort
  let state = {
  \ 'count': 0,
  \ 'target': len(a:Funcs),
  \ 'results': [],
  \ 'OnAllComplete': a:OnAllComplete
  \}
  for Func in a:Funcs
    call Func(function('s:AwaitFuncComplete', [state]))
  endfor
endfunction

" Call a list of async functions in sequence, and wait for them all to complete
" before calling the OnAllComplete function.
function! s:AwaitSequence(Funcs, OnAllComplete, ...) abort
  if a:0
    let state = a:1
  else
    let state = {
    \ 'count': 0,
    \ 'target': len(a:Funcs),
    \ 'results': [],
    \ 'OnAllComplete': a:OnAllComplete
    \}
  endif

  let Func = remove(a:Funcs, 0)
  let state.OnComplete = function('s:AwaitSequence', [a:Funcs, a:OnAllComplete])
  call Func(function('s:AwaitFuncComplete', [state]))
endfunction

function! s:AwaitFuncComplete(state, ...) abort
  if a:0 == 1
    call add(a:state.results, a:1)
  elseif a:0 > 1
    call add(a:state.results, a:000)
  endif
  let a:state.count += 1
  if a:state.count == a:state.target
    call a:state.OnAllComplete(a:state.results)
  elseif has_key(a:state, 'OnComplete')
    call a:state.OnComplete(a:state)
  endif
endfunction

function! s:LocationsFromResponse(quickfixes) abort
  let locations = []
  let overrides = get(g:, 'OmniSharp_diagnostic_overrides', {})
  for quickfix in a:quickfixes
    let text = get(quickfix, 'Text', get(quickfix, 'Message', ''))
    if get(g:, 'OmniSharp_diagnostic_showid', 0) && has_key(quickfix, 'Id')
      let text = quickfix.Id . ': ' . text
    endif
    if has_key(quickfix, 'FileName')
      let filename = OmniSharp#util#TranslatePathForClient(quickfix.FileName)
    else
      let filename = expand('%:p')
    endif
    let location = {
    \ 'filename': filename,
    \ 'text': text,
    \ 'lnum': quickfix.Line,
    \ 'col': quickfix.Column,
    \ 'vcol': 0
    \}
    if has_key(quickfix, 'EndLine') && has_key(quickfix, 'EndColumn')
      let location.end_lnum = quickfix.EndLine
      let location.end_col = quickfix.EndColumn - 1
    endif
    let loglevel = get(quickfix, 'LogLevel', '')
    if loglevel !=# ''
      let diag_id = get(quickfix, 'Id', '-')
      if index(keys(overrides), diag_id) >= 0
        if overrides[diag_id].type ==? 'None'
          continue
        endif
        call extend(location, overrides[diag_id])
      else
        let location.type = loglevel ==# 'Error' ? 'E' : 'W'
        if loglevel ==# 'Hidden'
          let location.subtype = 'Style'
        endif
      endif
    endif
    call add(locations, location)
  endfor
  return locations
endfunction

function! s:MakeChanges(body) abort
  let changes = get(a:body, 'Changes', [])
  if type(changes) == type(v:null) | let changes = [] | endif

  if len(changes)
    for change in changes
      let text = join(split(change.NewText, '\r\?\n', 1), "\n")
      let start = [change.StartLine, change.StartColumn]
      let end = [change.EndLine, change.EndColumn]
      call cursor(start)
      if change.StartColumn > len(getline('.')) && start != end
        " We can't set a mark after the last character of the line, so add an
        " extra charaqcter which will be immediately deleted again
        noautocmd normal! a<
      endif
      call cursor(change.EndLine, max([1, change.EndColumn - 1]))
      if change.StartLine < change.EndLine && change.EndColumn == 1
        " We can't delete before the first character of the line, so add an
        " extra charaqcter which will be immediately deleted again
        noautocmd normal! i>
      elseif start == end
        " Start and end are the same so insert a character to be replaced
        if change.StartColumn > 1
          normal! l
        endif
        noautocmd normal! i=
      endif
      call setpos("'[", [0, change.StartLine, change.StartColumn])
      let paste_bak = &paste | set paste
      silent execute "noautocmd keepjumps normal! v`[c\<C-r>=text\<CR>"
      let &paste = paste_bak
    endfor
  elseif get(a:body, 'Buffer', v:null) != v:null
    let pos = getpos('.')
    let lines = split(a:body.Buffer, '\r\?\n', 1)
    if len(lines) < line('$')
      if exists('*deletebufline')
        call deletebufline('%', len(lines) + 1, '$')
      else
        %delete
      endif
    endif
    call setline(1, lines)
    let pos[1] = min([pos[1], line('$')])
    call setpos('.', pos)
  endif
endfunction

function! OmniSharp#stdio#GetLogFile() abort
  return s:logfile
endfunction

function! OmniSharp#stdio#HandleResponse(job, message) abort
  try
    let res = json_decode(a:message)
  catch
    call s:Log(a:job.job_id . '  ' . a:message, 'info')
    call s:Log(a:job.job_id . '  JSON error: ' . v:exception, 'info')
    return
  endtry
  let loglevel =  get(res, 'Event', '') ==? 'log' ? 'info' : 'debug'
  call s:Log(a:job.job_id . '  ' . a:message, loglevel)
  if get(res, 'Type', '') ==# 'event'
    call s:HandleServerEvent(a:job, res)
    return
  endif
  if !has_key(res, 'Request_seq') || !has_key(s:requests, res.Request_seq)
    return
  endif
  let req = remove(s:requests, res.Request_seq)
  if has_key(req, 'ResponseHandler')
    if has_key(req, 'Request')
      call req.ResponseHandler(res, req.Request)
    else
      call req.ResponseHandler(res)
    endif
  endif
endfunction


function! OmniSharp#stdio#CodeCheck(opts, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeCheckRH', [a:Callback]),
  \ 'ReplayOnLoad': 1
  \}
  call extend(opts, a:opts, 'force')
  call s:Request('/codecheck', opts)
endfunction

function! s:CodeCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction


function! OmniSharp#stdio#GlobalCodeCheck(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:GlobalCodeCheckRH', [a:Callback])
  \}
  call s:RawRequest({}, '/codecheck', opts)
endfunction

function! s:GlobalCodeCheckRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:LocationsFromResponse(a:response.Body.QuickFixes))
endfunction


function! OmniSharp#stdio#CodeFormat(opts) abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeFormatRH', [a:opts]),
  \ 'ExpandTab': &expandtab,
  \ 'Parameters': {
  \   'WantsTextChanges': 1
  \ }
  \}
  call s:Request('/codeformat', opts)
endfunction

function! s:CodeFormatRH(opts, response) abort
  if !a:response.Success | return | endif
  normal! m'
  let winview = winsaveview()
  call s:MakeChanges(a:response.Body)
  call winrestview(winview)
  normal! ``
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction


function! OmniSharp#stdio#CodeStructure(bufnr, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:CodeStructureRH', [a:bufnr, a:Callback]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0
  \}
  call s:Request('/v2/codestructure', opts)
endfunction

function! s:CodeStructureRH(bufnr, Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(a:bufnr, a:response.Body.Elements)
endfunction


function! OmniSharp#stdio#FixUsings(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FixUsingsRH', [a:Callback]),
  \ 'Parameters': {
  \   'WantsTextChanges': 1
  \ }
  \}
  call s:Request('/fixusings', opts)
endfunction

function! OmniSharp#stdio#FindHighlightTypes(Callback) abort
  let bufferLines = getline(1, '$')
  let opts = {
  \ 'ResponseHandler': function('s:FindHighlightTypesRH', [a:Callback, bufferLines]),
  \ 'ReplayOnLoad': 1
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
    \ 'kind': hl.Kind,
    \ 'name': line[hl.StartColumn - 1 : hl.EndColumn - 2]
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
  let responses = a:response.Body.QuickFixes
  call a:Callback(type(responses) == type([]) ? s:LocationsFromResponse(responses) : [])
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


function! OmniSharp#stdio#FindTextProperties(bufnum) abort
  let buftick = getbufvar(a:bufnum, 'changedtick')
  let opts = {
  \ 'ResponseHandler': function('s:FindTextPropertiesRH', [a:bufnum, buftick]),
  \ 'ReplayOnLoad': 1
  \}
  call s:Request('/highlight', opts)
endfunction

function! s:FindTextPropertiesRH(bufnum, buftick, response) abort
  if !a:response.Success | return | endif
  if getbufvar(a:bufnum, 'changedtick') != a:buftick
    " The buffer has changed while fetching highlights - fetch fresh highlights
    " from the server
    call OmniSharp#stdio#FindTextProperties(a:bufnum)
    return
  endif
  let highlights = get(a:response.Body, 'Highlights', [])
  if !get(s:, 'textPropertiesInitialized', 0)
    let s:groupKinds = get(g:, 'OmniSharp_highlight_groups', {
    \ 'csUserIdentifier': [
    \   'constant name', 'enum member name', 'field name', 'identifier',
    \   'local name', 'parameter name', 'property name', 'static symbol'],
    \ 'csUserInterface': ['interface name'],
    \ 'csUserMethod': ['extension method name', 'method name'],
    \ 'csUserType': ['class name', 'enum name', 'namespace name', 'struct name']
    \})
    " Create the inverse dict for fast lookups
    let s:kindGroups = {}
    for key in keys(s:groupKinds)
      call prop_type_add(key, {'highlight': key, 'combine': 1})
      for kind in s:groupKinds[key]
        let s:kindGroups[kind] = key
      endfor
    endfor
    let s:textPropertiesInitialized = 1
  endif
  let curline = 1
  for hl in highlights
    if curline <= hl.StartLine
      call prop_clear(curline, hl.StartLine, {'bufnr': a:bufnum})
      let curline = hl.StartLine + 1
    endif
    if has_key(s:kindGroups, hl.Kind)
      try
        call prop_add(hl.StartLine, hl.StartColumn, {
        \ 'end_lnum': hl.EndLine,
        \ 'end_col': hl.EndColumn,
        \ 'type': s:kindGroups[hl.Kind],
        \ 'bufnr': a:bufnum
        \})
      catch /^Vim\%((\a\+)\)\=:\%(E275\|E964\):/
        " This response is for a hidden buffer, and 'nohidden' is in use.
        break
      endtry
    endif
    if get(g:, 'OmniSharp_highlight_debug', 0)
      let hlKind = 'cs' . substitute(hl.Kind, ' ', '_', 'g')
      if !len(prop_type_get(hlKind))
        call prop_type_add(hlKind, {'combine': 1})
      endif
      try
        call prop_add(hl.StartLine, hl.StartColumn, {
        \ 'end_lnum': hl.EndLine,
        \ 'end_col': hl.EndColumn,
        \ 'type': hlKind,
        \ 'bufnr': a:bufnum
        \})
      catch | endtry
    endif
  endfor
endfunction

function OmniSharp#stdio#HighlightEchoKind() abort
  let props = filter(prop_list(line('.')),
  \ 'v:val.col <= col(".") && v:val.col + v:val.length - 1 >= col(".")')
  if len(props)
    for prop in props
      if has_key(s:groupKinds, prop.type)
        echon ' (' . prop.type . ')'
      else
        echon substitute(props[0].type[2:], '_', ' ', 'g')
      endif
    endfor
  else
    echo 'No Kind found'
  endif
endfunction


function! OmniSharp#stdio#FindUsages(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FindUsagesRH', [a:Callback])
  \}
  call s:Request('/findusages', opts)
endfunction

function! s:FindUsagesRH(Callback, response) abort
  if !a:response.Success | return | endif
  let usages = a:response.Body.QuickFixes
  call a:Callback(type(usages) == type([]) ? s:LocationsFromResponse(a:response.Body.QuickFixes) : [])
endfunction


function! OmniSharp#stdio#FixUsings(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:FixUsingsRH', [a:Callback]),
  \ 'Parameters': {
  \   'WantsTextChanges': 1
  \ }
  \}
  call s:Request('/fixusings', opts)
endfunction

function! s:FixUsingsRH(Callback, response) abort
  if !a:response.Success | return | endif
  normal! m'
  let winview = winsaveview()
  call s:MakeChanges(a:response.Body)
  call winrestview(winview)
  normal! ``
  if type(a:response.Body.AmbiguousResults) == type(v:null)
    let locations = []
  else
    let locations = s:LocationsFromResponse(a:response.Body.AmbiguousResults)
  endif
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
    " In visual line mode, getpos("'>")[2] is a large number (2147483647).
    " When this value is too large, use the length of the line as the column
    " position.
    if end[2] > 99999
      let end[2] = len(getline(end[1]))
    endif
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
  else
    if exists('s:codeActionParameters')
      unlet s:codeActionParameters
    endif
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
      \ (cmp.DisplayText != v:null ? cmp.DisplayText : cmp.MethodHeader)
    endif
    let completion = {
    \ 'snip': get(cmp, 'Snippet', ''),
    \ 'word': word,
    \ 'menu': menu,
    \ 'icase': 1,
    \ 'dup': 1
    \}
    if g:omnicomplete_fetch_full_documentation
      let completion.info = ' '
      if has_key(cmp, 'Description') && cmp.Description != v:null
        let completion.info = cmp.Description
      endif
    endif
    call add(completions, completion)
  endfor
  call a:Callback(completions)
endfunction


function! OmniSharp#stdio#GotoDefinition(Callback) abort
  let parameters = {
  \ 'WantMetadata': v:true,
  \}
  let opts = {
  \ 'ResponseHandler': function('s:GotoDefinitionRH', [a:Callback]),
  \ 'Parameters': parameters
  \}
  call s:Request('/gotodefinition', opts)
endfunction

function! s:GotoDefinitionRH(Callback, response) abort
  if !a:response.Success | return | endif
  if get(a:response.Body, 'FileName', v:null) != v:null
    call a:Callback(s:LocationsFromResponse([a:response.Body])[0], a:response.Body)
  else
    call a:Callback(0, a:response.Body)
  endif
endfunction


function! OmniSharp#stdio#GotoMetadata(Callback, metadata) abort
  let opts = {
  \ 'ResponseHandler': function('s:GotoMetadataRH', [a:Callback, a:metadata]),
  \ 'Parameters': a:metadata.MetadataSource
  \}
  return s:Request('/metadata', opts)
endfunction

function! s:GotoMetadataRH(Callback, metadata, response) abort
  if !a:response.Success || a:response.Body.Source == v:null | return 0 | endif
  return a:Callback(a:response.Body, a:metadata)
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


function! OmniSharp#stdio#RenameTo(renameto, opts) abort
  let opts = {
  \ 'ResponseHandler': function('s:PerformChangesRH', [a:opts]),
  \ 'Parameters': {
  \   'RenameTo': a:renameto,
  \   'WantsTextChanges': 1
  \ }
  \}
  call s:Request('/rename', opts)
endfunction


function! OmniSharp#stdio#RunCodeAction(action, ...) abort
  let opts = {
  \ 'ResponseHandler': function('s:PerformChangesRH', [a:0 ? a:1 : {}]),
  \ 'Parameters': {
  \   'Identifier': a:action.Identifier,
  \   'WantsTextChanges': 1
  \ },
  \ 'UsePreviousPosition': 1
  \}
  if exists('s:codeActionParameters')
    call extend(opts.Parameters, s:codeActionParameters, 'force')
  endif
  call s:Request('/v2/runcodeaction', opts)
endfunction

function! s:PerformChangesRH(opts, response) abort
  if !a:response.Success | return | endif
  let changes = get(a:response.Body, 'Changes', [])
  if type(changes) != type([]) || len(changes) == 0
    echo 'No action taken'
  else
    let winview = winsaveview()
    let bufname = bufname('%')
    let bufnum = bufnr('%')
    let hidden_bak = &hidden | set hidden
    for change in changes
      call OmniSharp#JumpToLocation({
      \ 'filename': OmniSharp#util#TranslatePathForClient(change.FileName),
      \}, 1)
      call s:MakeChanges(change)
      if bufnr('%') != bufnum
        silent write | silent edit
      endif
    endfor
    if bufnr('%') != bufnum
      call OmniSharp#JumpToLocation({
      \ 'filename': bufname
      \}, 1)
    endif
    call winrestview(winview)
    let [line, col] = getpos("'`")[1:2]
    if line > 1 && col > 1
      normal! ``
    endif
    let &hidden = hidden_bak
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
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


function! OmniSharp#stdio#Project(bufnr, Callback) abort
  if has_key(OmniSharp#GetHost(a:bufnr), 'project')
    call a:Callback()
    return
  endif
  let opts = {
  \ 'ResponseHandler': function('s:ProjectRH', [a:Callback, a:bufnr]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0
  \}
  call s:Request('/project', opts)
endfunction

function! s:ProjectRH(Callback, bufnr, response) abort
  if !a:response.Success | return | endif
  let host = OmniSharp#GetHost(a:bufnr)
  let host.project = a:response.Body
  call a:Callback()
endfunction


let s:runningTest = 0

function! OmniSharp#stdio#RunTestsInFile(files, Callback) abort
  if s:runningTest
    echohl WarningMsg | echomsg 'A test is already running' | echohl None
    return
  endif
  let buffers = []
  for l:file in a:files
    let l:file = OmniSharp#util#TranslatePathForServer(l:file)
    let nr = bufnr(l:file)
    if nr == -1
      if filereadable(l:file)
        let nr = bufadd(l:file)
      else
        echohl WarningMsg | echomsg 'File not found: ' . l:file | echohl None
        continue
      endif
    endif
    call add(buffers, nr)
  endfor
  if len(buffers) == 0
    return
  endif
  let s:runningTest = 1
  call s:AwaitParallel(
  \ map(copy(buffers), {i,b -> function('OmniSharp#stdio#Project', [b])}),
  \ function('s:FindTestsInFiles', [a:Callback, buffers]))
endfunction

function! s:FindTestsInFiles(Callback, buffers, ...) abort
  call s:AwaitParallel(
  \ map(copy(a:buffers), {i,b -> function('OmniSharp#stdio#CodeStructure', [b])}),
  \ function('s:RunTestsInFiles', [a:Callback]))
endfunction

function! s:RunTestsInFiles(Callback, bufferCodeStructures) abort
  let Requests = []
  for bcs in a:bufferCodeStructures
    let bufnr = bcs[0]
    let codeElements = bcs[1]
    let tests = s:FindTests(codeElements)
    if len(tests)
      call add(Requests, function('s:RunTestsInFile', [bufnr, tests]))
    endif
  endfor
  if len(Requests) == 0
    echohl WarningMsg | echom 'No tests found' | echohl None
    let s:runningTest = 0
    return
  endif
  if g:OmniSharp_runtests_parallel
    if g:OmniSharp_runtests_echo_output
      echomsg '---- Running tests ----'
    endif
    call s:AwaitParallel(Requests, a:Callback)
  else
    call s:AwaitSequence(Requests, a:Callback)
  endif
endfunction

function! s:RunTestsInFile(bufnr, tests, Callback) abort
  if !g:OmniSharp_runtests_parallel && g:OmniSharp_runtests_echo_output
    echomsg '---- Running tests: ' . bufname(a:bufnr) . ' ----'
  endif
  let project = OmniSharp#GetHost(a:bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': function('s:RunTestsRH', [a:Callback, a:bufnr, a:tests]),
  \ 'BufNum': a:bufnr,
  \ 'Parameters': {
  \   'MethodNames': map(copy(a:tests), {i,t -> t.name}),
  \   'TestFrameworkName': a:tests[0].framework,
  \   'TargetFrameworkVersion': targetFramework
  \ },
  \ 'SendBuffer': 0
  \}
  call s:Request('/v2/runtestsinclass', opts)
endfunction

function! OmniSharp#stdio#RunTest(bufnr, Callback) abort
  if s:runningTest
    echohl WarningMsg | echomsg 'A test is already running' | echohl None
    return
  endif
  if !has_key(OmniSharp#GetHost(a:bufnr), 'project')
    " Initialize the test by fetching the project for the buffer - then call
    " this function again in the callback
    call OmniSharp#stdio#Project(a:bufnr,
    \ function('OmniSharp#stdio#RunTest', [a:bufnr, a:Callback]))
    return
  endif
  let s:runningTest = 1
  call OmniSharp#stdio#CodeStructure(a:bufnr,
  \ function('s:RunTest', [a:Callback]))
endfunction

function! s:RunTest(Callback, bufnr, codeElements) abort
  let tests = s:FindTests(a:codeElements)
  let currentTest = s:FindTest(tests)
  if type(currentTest) != type({})
    echohl WarningMsg | echom 'No test found' | echohl None
    let s:runningTest = 0
    return
  endif
  let project = OmniSharp#GetHost(a:bufnr).project
  let targetFramework = project.MsBuildProject.TargetFramework
  let opts = {
  \ 'ResponseHandler': function('s:RunTestsRH', [a:Callback, a:bufnr, tests]),
  \ 'Parameters': {
  \   'MethodName': currentTest.name,
  \   'TestFrameworkName': currentTest.framework,
  \   'TargetFrameworkVersion': targetFramework
  \ },
  \ 'SendBuffer': 0
  \}
  echomsg 'Running test ' . currentTest.name
  call s:Request('/v2/runtest', opts)
endfunction

function! s:RunTestsRH(Callback, bufnr, tests, response) abort
  let s:runningTest = 0
  if !a:response.Success | return | endif
  if type(a:response.Body.Results) != type([])
    echohl WarningMsg
    echom 'Error: "'  . a:response.Body.Failure .
    \ '"   - this may indicate a failed build'
    echohl None
    return
  endif
  let summary = {
  \ 'pass': a:response.Body.Pass,
  \ 'locations': []
  \}
  for result in a:response.Body.Results
    " Strip namespace and classname from test method name
    let location = {
    \ 'filename': bufname(a:bufnr),
    \ 'name': substitute(result.MethodName, '^.*\.', '', '')
    \}
    if result.Outcome =~? 'failed'
      let location.type = 'E'
      let location.text = location.name . ': ' . result.ErrorMessage
      let parsed = matchlist(result.ErrorStackTrace, ' in \(.\+\):line \(\d\+\)')
      if len(parsed) == 0
        echohl WarningMsg
        echom 'Could not create quickfix from test failure'
        echohl None
        echom location.text
        echom result.ErrorStackTrace
        continue
      endif
      let location.lnum = parsed[2]
    else
      let location.text = location.name . ': ' . result.Outcome
      let test = s:FindTest(a:tests, result.MethodName)
      if type(test) == type({})
        let location.lnum = test.nameRange.Start.Line
        let location.col = test.nameRange.Start.Column
        let location.vcol = 0
      endif
    endif
    call add(summary.locations, location)
  endfor
  call a:Callback(summary)
endfunction

function! s:FindTest(tests, ...) abort
  for test in a:tests
    if a:0
      if test.name ==# a:1
        return test
      endif
    else
      if line('.') >= test.range.Start.Line && line('.') <= test.range.End.Line
        return test
      endif
    endif
  endfor
  return 0
endfunction

function! s:FindTests(codeElements) abort
  if type(a:codeElements) != type([]) | return [] | endif
  let tests = []
  for element in a:codeElements
    if has_key(element, 'Properties')
    \ && type(element.Properties) == type({})
    \ && has_key(element.Properties, 'testMethodName')
    \ && has_key(element.Properties, 'testFramework')
      call add(tests, {
      \ 'name': element.Properties.testMethodName,
      \ 'framework': element.Properties.testFramework,
      \ 'range': element.Ranges.full,
      \ 'nameRange': element.Ranges.name,
      \})
    endif
    call extend(tests, s:FindTests(get(element, 'Children', [])))
  endfor
  return tests
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
    return
  endif
  let body = a:response.Body
  call a:Callback({
  \ 'type': body.Type != v:null ? body.Type : '',
  \ 'doc': body.Documentation != v:null ? body.Documentation : ''
  \})
endfunction


function! OmniSharp#stdio#UpdateBuffer(opts) abort
  let opts = {
  \ 'ResponseHandler': function('s:UpdateBufferRH', [a:opts])
  \}
  call s:Request('/updatebuffer', opts)
endfunction

function! s:UpdateBufferRH(opts, response) abort
  if has_key(a:opts, 'Callback')
    call a:opts.Callback()
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
