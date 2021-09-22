let s:save_cpo = &cpoptions
set cpoptions&vim

let s:attempts = 0

function! OmniSharp#actions#workspace#Get(job) abort
  let opts = {
  \ 'ResponseHandler': function('s:ProjectsRH', [a:job])
  \}
  let s:attempts += 1
  call OmniSharp#stdio#RequestGlobal(a:job, '/projects', opts)
endfunction

function! s:ProjectsRH(job, response) abort
  " If this request fails, retry up to 5 times
  if !a:response.Success
    if s:attempts < 5
      call OmniSharp#actions#workspace#Get(a:job)
    endif
    return
  endif
  " If no projects have been loaded by the time this callback is reached, there
  " are no projects and the job can be marked as ready
  let projects = get(get(a:response.Body, 'MsBuild', {}), 'Projects', {})
  let a:job.projects = map(projects,
  \ {_,project -> {"name": project.AssemblyName, "path": project.Path, "target": project.TargetPath}})
  if get(a:job, 'projects_total', 0) > 0
    call OmniSharp#log#Log(a:job, 'Workspace complete: ' . a:job.projects_total . ' project(s)')
  else
    call OmniSharp#log#Log(a:job, 'Workspace complete: no projects')
    call OmniSharp#project#RegisterLoaded(a:job)
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
