let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#project#Get(bufnr, Callback) abort
  if has_key(OmniSharp#GetHost(a:bufnr), 'project')
    call a:Callback(v:true)
    return
  endif
  let opts = {
  \ 'ResponseHandler': function('s:ProjectRH', [a:Callback, a:bufnr]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0
  \}
  call OmniSharp#stdio#Request('/project', opts)
endfunction

function! s:ProjectRH(Callback, bufnr, response) abort
  if !a:response.Success
    call a:Callback(v:false)
  else
    let host = getbufvar(a:bufnr, 'OmniSharp_host')
    let host.project = a:response.Body
    call a:Callback(v:true)
  endif
endfunction

function! PrintProjectLoadFailed() abort
  echohl ErrorMsg
  echomsg 'Failure getting project info. Check :OmniSharpOpenLog'
  echohl None
endfunction

function! OmniSharp#actions#project#DebugProject(stopAtEntry, ...) abort
  if !OmniSharp#util#HasVimspector()
    echohl WarningMsg
    echomsg 'Vimspector required to debug project'
    echohl None
    return
  endif
  let bufnr = bufnr('%')
  function! DebugProjectCb(bufnr, stopAtEntry, args, success) abort
    let project = getbufvar(a:bufnr, 'OmniSharp_host').project
    " Make sure we're not running on a csx script
    if !a:success
      call PrintProjectLoadFailed()
    elseif project.ScriptProject is v:null
      let programPath = project.MsBuildProject.TargetPath
      if has('win32') | let programPath = substitute(programPath, '\', '/', 'g') | endif
      call vimspector#LaunchWithConfigurations({
      \  'launch': {
      \    'adapter': 'netcoredbg',
      \    'configuration': {
      \      'request': 'launch',
      \      'program': programPath,
      \      'args': a:args,
      \      'stopAtEntry#json': a:stopAtEntry ? 'true' : 'false'
      \    }
      \  }
      \})
    else
      echohl WarningMsg
      echomsg 'DebugProject is not currently implemented for csx files'
      echohl None
    endif
  endfunction
  call OmniSharp#actions#project#Get(bufnr, function('DebugProjectCb', [bufnr, a:stopAtEntry, a:000]))
endfunction

function! OmniSharp#actions#project#CreateDebugConfig(stopAtEntry, ...) abort
  let bufnr = bufnr('%')
  function! CreateDebugConfigCb(bufnr, stopAtEntry, args, success) abort
    if !a:success
      call PrintProjectLoadFailed()
    else
      let host = getbufvar(a:bufnr, 'OmniSharp_host')
      let programPath = host.project.MsBuildProject.TargetPath
      if has('win32') | let programPath = substitute(programPath, '\', '/', 'g') | endif
      let contents = [
            \' {',
            \'   "configurations": {',
            \'     "attach": {',
            \'       "adapter": "netcoredbg",',
            \'       "configuration": {',
            \'         "request": "attach",',
            \'         "processId": "${pid}"',
            \'       }',
            \'     },',
            \'     "launch": {',
            \'       "adapter": "netcoredbg",',
            \'       "configuration": {',
            \'         "request": "launch",',
            \'         "program": "'.programPath.'",',
            \'         "args": ' . json_encode(a:args) . ',',
            \'         "stopAtEntry": ' . (a:stopAtEntry ? 'true' : 'false'),
            \'       }',
            \'     }',
            \'   }',
            \' }',
      \ ]
      if isdirectory(host.sln_or_dir)
        let hostdir = host.sln_or_dir
      else
        let hostdir = fnamemodify(host.sln_or_dir, ':h:p')
      endif
      let filename = hostdir . '/.vimspector.json'
      call writefile(contents, filename)
      execute 'edit ' . filename
    endif
    if !OmniSharp#util#HasVimspector()
      echohl WarningMsg
      echomsg 'Vimspector does not seem to be installed. You will need it to run the created configuration.'
      echohl None
    endif
  endfunction
  call OmniSharp#actions#project#Get(bufnr, function('CreateDebugConfigCb', [bufnr, a:stopAtEntry, a:000]))
endfunction

function! OmniSharp#actions#project#Complete(arglead, cmdline, cursorpos) abort
  let job = OmniSharp#GetHost(bufnr()).job
  if !has_key(job, 'projects') | return [] | endif
  let projectPaths = map(copy(job.projects), {_,p -> fnamemodify(p.path, ':.')})
  return filter(projectPaths, {_,path -> path =~? a:arglead})
endfunction

function! OmniSharp#actions#project#Reload(projectFile) abort
  if len(a:projectFile) == 0
    call s:ReloadProjectForBuffer(bufnr())
    return
  endif
  if !filereadable(a:projectFile)
    call OmniSharp#util#EchoErr('File ' . a:projectFile . ' cannot be read')
    return
  endif
  echohl Title
  echomsg 'Reloading ' . fnamemodify(a:projectFile, ':t')
  echohl None
  let opts = {
  \ 'SendBuffer': 0,
  \ 'Arguments': [{
  \   'FileName': fnamemodify(a:projectFile, ':p'),
  \   'ChangeType': 'Change'
  \ }]
  \}
  let job = OmniSharp#GetHost(bufnr()).job
  let job.loaded = 0
  let job.projects_loaded -= 1
  let job.restart_time = reltime()
  let job.restart_project = fnamemodify(a:projectFile, ':t')
  call OmniSharp#stdio#Request('/filesChanged', opts)
endfunction

function! s:ReloadProjectForBuffer(bufnr) abort
  call OmniSharp#actions#project#Get(a:bufnr, function('s:ReloadCB', [a:bufnr]))
endfunction

function! s:ReloadCB(bufnr, success) abort
  if a:success
    let project = OmniSharp#GetHost(a:bufnr).project
    let projectFile = project.MsBuildProject.Path
    call OmniSharp#actions#project#Reload(projectFile)
  else
    echohl WarningMsg
    echomsg 'Project could not be found. Try reloading the project by name.'
    echohl None
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
