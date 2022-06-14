let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = get(s:, 'nextseq', 1001)
let s:requests = get(s:, 'requests', {})

function! OmniSharp#stdio#HandleResponse(job, message) abort
  try
    let res = json_decode(a:message)
    let a:job.logsize = get(a:job, 'logsize', 0) + 1
  catch
    let a:job.json_errors = get(a:job, 'json_errors', 0) + 1
    if !OmniSharp#proc#IsJobRunning(a:job) || get(a:job, 'stopping')
      return
    endif
    if a:job.json_errors >= 10 && get(a:job, 'logsize', 0) < 10 && !a:job.loaded
      call OmniSharp#log#Log(a:job, '10 errors caught while loading: stopping')
      call OmniSharp#proc#StopJob(a:job.sln_or_dir)
      echohl WarningMsg
      echomsg 'You appear to be running an HTTP server in stdio mode - ' .
      \ 'upgrade to the stdio server with :OmniSharpInstall, or to continue ' .
      \' in HTTP mode add the following to your .vimrc and restart Vim:  '
      \ 'let g:OmniSharp_server_stdio = 0'
      echohl None
      return
    endif
    call OmniSharp#log#Log(a:job, a:message)
    call OmniSharp#log#Log(a:job, 'JSON error: ' . v:exception)
    return
  endtry
  call OmniSharp#log#LogServer(a:job, a:message, res)
  if get(res, 'Type', '') ==# 'event'
    call s:HandleServerEvent(a:job, res)
    return
  endif
  if !has_key(res, 'Request_seq') || !has_key(s:requests, res.Request_seq)
    return
  endif
  let req = remove(s:requests, res.Request_seq)
  let elapsed = reltimefloat(reltime(req.StartTime))
  call OmniSharp#log#Log(
  \ a:job,
  \ printf('Response: %s after %.3f', req.Command, elapsed),
  \ 1)
  if has_key(req, 'ResponseHandler')
    if has_key(req, 'Request')
      call req.ResponseHandler(res, req.Request)
    else
      call req.ResponseHandler(res)
    endif
  endif
endfunction

function! s:HandleServerEvent(job, res) abort
  let body = get(a:res, 'Body', 0)
  if type(body) != type({})
    let body = {}
  endif

  " Handle any project loading events
  call OmniSharp#project#ParseEvent(a:job, get(a:res, 'Event', ''), body)

  if !empty(body)

    " Listen for diagnostics.
    " When OmniSharp-roslyn is configured with `EnableAnalyzersSupport`, the
    " first diagnostic or code action request will trigger analysis of ALL
    " solution documents.
    " These diagnostics results are sent out over stdio so we can capture them
    " and update ALE for loaded buffers. This is necessary because, especially
    " when the project is first loading, the requested diagnostics are often
    " wrong and quickly replaced by correct, unsolicited diagnostics.
    if g:OmniSharp_diagnostic_listen > 0 &&
    \ has_key(g:, 'OmniSharp_diagnostics_requested')
      if get(a:res, 'Event', '') ==# 'Diagnostic'
        for result in get(body, 'Results', [])
          let fname = OmniSharp#util#TranslatePathForClient(result.FileName)
          let bufinfo = getbufinfo(fname)
          if len(bufinfo) == 0 || !has_key(bufinfo[0], 'bufnr')
            continue
          endif
          let bufnr = bufinfo[0].bufnr
          if g:OmniSharp_diagnostic_listen == 1
            let host = getbufvar(bufnr, 'OmniSharp_host')
            if get(host, 'diagnostics_received')
              continue
            endif
            let host.diagnostics_received = 1
          endif
          call ale#other_source#StartChecking(bufnr, 'OmniSharp')
          let opts = { 'BufNum': bufnr }
          let qfs = OmniSharp#actions#diagnostics#Parse(result.QuickFixes)
          let counts = {}
          for sev in ['E', 'W', 'I']
            let counts[sev] = len(filter(copy(qfs), {_,qf -> qf.type ==# sev}))
          endfor
          call OmniSharp#log#Log(
          \ a:job,
          \ printf('Diagnostics received for %s, E:%d W:%d I:%d',
          \   fname, counts.E, counts.W, counts.I),
          \ 1)
          call ale#sources#OmniSharp#ProcessResults(opts, qfs)
        endfor
      endif
    endif

    " Diagnostics received while running tests
    if get(a:res, 'Event', '') ==# 'TestMessage'
      let lines = split(body.Message, '\r\?\n')
      call OmniSharp#testrunner#Log(lines)
      for line in lines
        if get(body, 'MessageLevel', '') ==# 'error'
          echohl WarningMsg | echomsg line | echohl None
        elseif g:OmniSharp_runtests_echo_output
          echomsg line
        endif
      endfor
    endif

  endif
endfunction

function! OmniSharp#stdio#Request(command, opts) abort
  if get(a:opts, 'UsePreviousPosition', 0)
    let [bufnr, lnum, cnum] = s:lastPosition
  elseif has_key(a:opts, 'BufNum') && a:opts.BufNum != bufnr('%')
    let bufnr = a:opts.BufNum
    let lnum = get(a:opts, 'LineNum', 1)
    let cnum = get(a:opts, 'ColNum', 1)
  else
    let bufnr = bufnr('%')
    let lnum = get(a:opts, 'LineNum', line('.'))
    if exists('*charcol')
      " charcol() gives the character index of the cursor column, instead of the
      " byte index. The OmniSharp-roslyn server uses character-based indices.
      let cnum = get(a:opts, 'ColNum', charcol('.'))
    else
      let cnum = get(a:opts, 'ColNum', col('.'))
    endif
  endif
  let host = OmniSharp#GetHost(bufnr)
  let job = host.job
  if !OmniSharp#proc#IsJobRunning(job)
    return 0
  endif

  if get(a:opts, 'Initializing', 0)
    " The buffer is being initialized - this request will always be sent
  else
    if !get(host, 'initialized')
      " Replay the request when the buffer has been initialized with the server
      let opts = extend(a:opts, {
      \ 'BufNum': bufnr,
      \ 'LineNum': lnum,
      \ 'ColNum': cnum
      \})
      if has_key(opts, 'UsePreviousPosition')
        unlet opts.UsePreviousPosition
      endif
      call OmniSharp#buffer#Initialize(job, bufnr, a:command, opts)
      return 0
    endif
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

  if has_key(a:opts, 'Arguments')
    let body = {
    \ 'Arguments': a:opts.Arguments
    \}
  else
    let body = {
    \ 'Arguments': {
    \   'FileName': filename,
    \   'Line': lnum,
    \   'Column': cnum,
    \ }
    \}
  endif
  if has_key(a:opts, 'EmptyBuffer')
    let body.Arguments.Buffer = ''
    let sep = ''
  elseif send_buffer
    let lines = getbufline(bufnr, 1, '$')
    if has_key(a:opts, 'OverrideBuffer')
      let lines[a:opts.OverrideBuffer.LineNr - 1] = a:opts.OverrideBuffer.Line
      let cnum = a:opts.OverrideBuffer.Col
    endif
    if &endofline
      " Ensure that the final trailing <EOL> is included, so that EOL analyzers
      " won't complain about missing <EOL> on the final line when it does
      " actually exist, it just isn't displayed by vim.
      call add(lines, '')
    endif
    let tmp = join(lines, '')
    " Unique string separator which must not exist in the buffer
    let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
    while stridx(tmp, sep) >= 0
      let sep = '@' . matchstr(reltimestr(reltime()), '\v\.@<=\d+') . '@'
    endwhile
    let body.Arguments.Buffer = join(lines, sep)
  else
    let sep = ''
  endif

  call s:Request(job, body, a:command, a:opts, sep, bufnr)

  if has_key(a:opts, 'ReplayOnLoad')
    let replay_opts = filter(copy(a:opts), 'v:key !=# "ReplayOnLoad"')
    call s:QueueForReplayOnLoad(job, bufnr, a:command, replay_opts)
  endif

  return 1
endfunction

function! OmniSharp#stdio#RequestGlobal(job, command, opts) abort
  call s:Request(a:job, {}, a:command, a:opts, '', -1)
endfunction

function! s:Request(job, body, command, opts, sep, bufnr) abort
  call OmniSharp#log#Log(a:job, 'Request: ' . a:command, 1)

  let a:body['Command'] = a:command
  let a:body['Seq'] = s:nextseq
  let a:body['Type'] = 'request'
  if has_key(a:opts, 'Parameters')
    call extend(a:body.Arguments, a:opts.Parameters, 'force')
  endif
  if a:sep !=# ''
    let encodedBody = substitute(json_encode(a:body), a:sep, '\\r\\n', 'g')
  else
    let encodedBody = json_encode(a:body)
  endif

  let s:requests[s:nextseq] = {
  \ 'BufNum': a:bufnr,
  \ 'Command': a:command,
  \ 'Seq': s:nextseq,
  \ 'StartTime': reltime()
  \}
  if has_key(a:opts, 'ResponseHandler')
    let s:requests[s:nextseq].ResponseHandler = a:opts.ResponseHandler
  endif
  let s:nextseq += 1
  if get(g:, 'OmniSharp_proc_debug')
    " The raw request is already logged by the server in debug mode.
    call OmniSharp#log#Log(a:job, encodedBody, 1)
  endif
  if has('nvim')
    call chansend(a:job.job_id, encodedBody . "\n")
  else
    call ch_sendraw(a:job.job_id, encodedBody . "\n")
  endif
endfunction

function! s:QueueForReplayOnLoad(job, bufnr, command, opts) abort
  if type(a:job) == type({}) && !get(a:job, 'loaded')
    " The project is still loading - it is possible to highlight but those
    " highlights will be improved once loading is complete, so listen for that
    " and re-run the highlighting on project load.
    let pending = get(a:job, 'pending_load_requests', {})
    let pending[a:bufnr] = get(pending, a:bufnr, {})
    let pending[a:bufnr][a:command] = a:opts
    let a:job.pending_load_requests = pending
  endif
endfunction

function! OmniSharp#stdio#ReplayOnLoad(job, ...) abort
  call OmniSharp#log#Log(a:job, 'Replaying on-load requests')
  for bufnr in keys(get(a:job, 'pending_load_requests', {}))
    for key in keys(a:job.pending_load_requests[bufnr])
      call OmniSharp#stdio#Request(key, a:job.pending_load_requests[bufnr][key])
      unlet a:job.pending_load_requests[bufnr][key]
    endfor
    unlet a:job.pending_load_requests[bufnr]
  endfor
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
