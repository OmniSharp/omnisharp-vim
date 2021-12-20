let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#project#Get(bufnr, Callback) abort
  if has_key(OmniSharp#GetHost(a:bufnr), 'project')
    call a:Callback()
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
  if !a:response.Success | return | endif
  let host = getbufvar(a:bufnr, 'OmniSharp_host')
  let host.project = a:response.Body
  call a:Callback()
endfunction

function! OmniSharp#actions#project#DebugProject(stopAtEntry, ...) abort
  if !OmniSharp#util#HasVimspector()
    echohl WarningMsg
    echomsg 'Vimspector required to debug project'
    echohl None
    return
  endif
  let bufnr = bufnr('%')
  function! DebugProjectCb(bufnr, stopAtEntry, args) abort
    let project = getbufvar(a:bufnr, 'OmniSharp_host').project
    " Make sure we're not running on a csx script
    if project.ScriptProject is v:null
      let programPath = project.MsBuildProject.TargetPath
      if has('win32') | let programPath = substitute(programPath, '\', '/', 'g') | endif
      call vimspector#LaunchWithConfigurations({
      \  'launch': {
      \    'adapter': 'netcoredbg',
      \    'configuration': {
      \      'request': 'launch',
      \      'program': programPath,
      \      'args': a:args,
      \      'stopAtEntry': a:stopAtEntry ? v:true : v:false
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
  function! CreateDebugConfigCb(bufnr, stopAtEntry, args) abort
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
    if !OmniSharp#util#HasVimspector()
      echohl WarningMsg
      echomsg 'Vimspector does not seem to be installed. You will need it to run the created configuration.'
      echohl None
    endif
  endfunction
  call OmniSharp#actions#project#Get(bufnr, function('CreateDebugConfigCb', [bufnr, a:stopAtEntry, a:000]))
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
