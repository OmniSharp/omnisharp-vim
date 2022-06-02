let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#testrunner#Open() abort
  if !OmniSharp#actions#test#Validate() | return | endif
  call s:Open()
endfunction

function s:Open() abort
  let ft = 'omnisharptest'
  let title = 'OmniSharp Test Runner'
  " If the buffer is listed in a window in the current tab, then focus it
  for winnr in range(1, winnr('$'))
    if getbufvar(winbufnr(winnr), '&filetype') ==# ft
      call win_gotoid(win_getid(winnr))
      break
    endif
  endfor
  if &filetype !=# ft
    " If a buffer with filetype omnisharptest exists, open it in a new split
    for buffer in getbufinfo()
      if getbufvar(buffer.bufnr, '&filetype') ==# ft
        botright split
        execute 'buffer' buffer.bufnr
        break
      endif
    endfor
  endif
  if &filetype !=# ft
    botright new
  endif

  silent setlocal noswapfile signcolumn=no
  set bufhidden=hide
  let &filetype = ft
  execute 'file' title
  call s:Paint()
endfunction

function! s:Paint() abort
  setlocal modifiable
  let winview = winsaveview()
  0,$delete _
  put ='OmniSharp Test Runner'
  0delete _
  put =''

  for sln_or_dir in OmniSharp#proc#ListRunningJobs()
    put =fnamemodify(sln_or_dir, ':t')
    let job = OmniSharp#proc#GetJob(sln_or_dir)
    if !has_key(job, 'tests') | continue | endif
    for testfile in keys(job.tests)
      put ='  ' . fnamemodify(testfile, ':.')
      for test in job.tests[testfile]
        put ='    ' . test.name
      endfor
    endfor
    put =''
  endfor

  call winrestview(winview)
  setlocal nomodifiable nomodified
endfunction

function! OmniSharp#testrunner#SetTests(bufferTests) abort
  let winid = win_getid()
  for buffer in a:bufferTests
    let job = OmniSharp#GetHost(buffer.bufnr).job
    let job.tests = get(job, 'tests', {})
    let filename = fnamemodify(bufname(buffer.bufnr), ':p')
    let job.tests[filename] = buffer.tests
  endfor
  call s:Open()
  call win_gotoid(winid)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
