let s:save_cpo = &cpoptions
set cpoptions&vim

let s:nextseq = get(s:, 'nextseq', 1001)
let s:requests = get(s:, 'requests', {})
let s:pendingRequests = get(s:, 'pendingRequests', {})

function! OmniSharp#stdio#HandleResponse(job, message) abort
  try
    let res = json_decode(a:message)
  catch
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
          \ || message =~# '^Failed to load project'
            if message[0] ==# 'F'
              echom 'Failed to load project: ' . project
            endif
            call filter(a:job.loading, {idx,val -> val !=# project})
            if len(a:job.loading) == 0
              if g:OmniSharp_server_display_loading
                let elapsed = reltimefloat(reltime(a:job.start_time))
                echomsg printf('Loaded server for %s in %.1fs',
                \ a:job.sln_or_dir, elapsed)
              endif
              let a:job.loaded = 1
              silent doautocmd <nomodeline> User OmniSharpReady

              " TODO: Remove this delay once we have better information about
              " when the server is completely initialised:
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
            let bufnr = bufinfo[0].bufnr
            call ale#other_source#StartChecking(bufnr, 'OmniSharp')
            let opts = { 'BufNum': bufnr }
            let quickfixes = OmniSharp#locations#Parse(result.QuickFixes)
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

function! s:ReplayRequests(...) abort
  for key in keys(s:pendingRequests)
    call OmniSharp#stdio#Request(key, s:pendingRequests[key])
    unlet s:pendingRequests[key]
  endfor
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
