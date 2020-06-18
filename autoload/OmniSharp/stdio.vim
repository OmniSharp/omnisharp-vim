let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = get(s:, 'nextseq', 1001)
let s:requests = get(s:, 'requests', {})
let s:pendingRequests = get(s:, 'pendingRequests', {})

function! OmniSharp#stdio#HandleResponse(job, message) abort
  try
    let res = json_decode(a:message)
  catch
    let a:job.json_errors = get(a:job, 'json_errors', 0) + 1
    if !OmniSharp#proc#IsJobRunning(a:job)
      return
    endif
    if a:job.json_errors >= 3 && !a:job.loaded
      call OmniSharp#log#Log('3 errors caught while loading: stopping', 'info')
      call OmniSharp#proc#StopJob(a:job.sln_or_dir)
      echohl WarningMsg
      echomsg 'You appear to be running an HTML server in stdio mode - ' .
      \ 'upgrade to the stdio server with :OmniSharpInstall, or to continue ' .
      \' in HTTP mode add the following to your .vimrc and restart Vim:  '
      \ 'let g:OmniSharp_server_stdio = 0'
      echohl None
      return
    endif
    call OmniSharp#log#Log(a:job.job_id . '  ' . a:message, 'info')
    call OmniSharp#log#Log(a:job.job_id . '  JSON error: ' . v:exception, 'info')
    return
  endtry
  let loglevel =  get(res, 'Event', '') ==? 'log' ? 'info' : 'debug'
  call OmniSharp#log#Log(a:job.job_id . '  ' . a:message, loglevel)
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

function! s:HandleServerEvent(job, res) abort
  if has_key(a:res, 'Body') && type(a:res.Body) == type({})

    " Handle any project loading events
    call OmniSharp#project#ParseEvent(a:job, a:res.Body)

    " Listen for diagnostics.
    " The OmniSharp-roslyn server starts sending diagnostics once projects are
    " loaded, which e.g. VSCode uses to populate project-wide warnings.
    " We don't do that, and it doesn't make a lot of sense in a Vim workflow, so
    " parsing these diagnostics is disabled by default.
    if get(g:, 'OmniSharp_diagnostics_listen', 0)
    \ && has_key(g:, 'OmniSharp_ale_diagnostics_requested')
      if get(a:res, 'Event', '') ==# 'Diagnostic'
        for result in get(a:res.Body, 'Results', [])
          let fname = OmniSharp#util#TranslatePathForClient(result.FileName)
          let bufinfo = getbufinfo(fname)
          if len(bufinfo) == 0 || !has_key(bufinfo[0], 'bufnr')
            continue
          endif
          let bufnr = bufinfo[0].bufnr
          call ale#other_source#StartChecking(bufnr, 'OmniSharp')
          let opts = { 'BufNum': bufnr }
          let quickfixes = OmniSharp#locations#Parse(result.QuickFixes)
          call ale#sources#OmniSharp#ProcessResults(opts, quickfixes)
        endfor
      endif
    endif

    " Diagnostics received while running tests
    if get(a:res, 'Event', '') ==# 'TestMessage'
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
endfunction

function! OmniSharp#stdio#Request(command, opts) abort
  if has_key(a:opts, 'UsePreviousPosition')
    let [bufnr, lnum, cnum] = s:lastPosition
  elseif has_key(a:opts, 'BufNum') && a:opts.BufNum != bufnr('%')
    let bufnr = a:opts.BufNum
    let lnum = 1
    let cnum = 1
  else
    let bufnr = bufnr('%')
    let lnum = line('.')
    let cnum = col('.')
  endif
  if has_key(a:opts, 'SavePosition')
    let s:lastPosition = [bufnr, lnum, cnum]
  endif
  let metadata_filename = get(b:, 'OmniSharp_metadata_filename', v:null)
  let is_metadata = type(metadata_filename) == type('')
  if is_metadata
    let filename = metadata_filename
    let send_buffer = 0
  else
    let filename = OmniSharp#util#TranslatePathForServer(
    \ fnamemodify(bufname(bufnr), ':p'))
    let send_buffer = get(a:opts, 'SendBuffer', 1)
  endif
  let lines = getbufline(bufnr, 1, '$')
  if has_key(a:opts, 'OverrideBuffer')
    let lines[a:opts.OverrideBuffer.LineNr - 1] = a:opts.OverrideBuffer.Line
    let cnum = a:opts.OverrideBuffer.Col
  endif
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
  return OmniSharp#stdio#RequestSend(body, a:command, a:opts, sep)
endfunction

function! OmniSharp#stdio#RequestSend(body, command, opts, ...) abort
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
  call OmniSharp#log#Log(job_id . '  Request: ' . a:command, 'debug')

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
  call OmniSharp#log#Log(encodedBody, 'debug')
  if has('nvim')
    call chansend(job_id, encodedBody . "\n")
  else
    call ch_sendraw(job_id, encodedBody . "\n")
  endif
  return 1
endfunction

function! OmniSharp#stdio#ReplayRequests(...) abort
  for key in keys(s:pendingRequests)
    call OmniSharp#stdio#Request(key, s:pendingRequests[key])
    unlet s:pendingRequests[key]
  endfor
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
