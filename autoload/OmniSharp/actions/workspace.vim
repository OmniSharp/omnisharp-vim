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

  let projectFolders = mapnew(projects, {_,p -> fnamemodify(p.path, ':p:h') })
  for i in filter(range(1, bufnr('$')), {_,x -> bufexists(x) && !empty(getbufvar(x, "OmniSharp_host")) && getbufvar(x, "OmniSharp_host").sln_or_dir != a:job.sln_or_dir})
    let host = getbufvar(i, "OmniSharp_host")
    let filePath = fnamemodify(bufname(i), ':p')
    for projectFolder in projectFolders
      if stridx(filePath, projectFolder) == 0
        let host.sln_or_dir = a:job.sln_or_dir
        break
      endif
    endfor
  endfor

  if a:job.sln_or_dir =~ '\.sln$' && get(g:, 'OmniSharp_stop_redundant_servers', 1)
    for runningJob in OmniSharp#proc#ListRunningJobs()
      let isCompletelyCoveredByNewestSolution = 1
      let runningJobProjectsPaths = mapnew(OmniSharp#proc#GetJob(runningJob).projects, "fnamemodify(v:val.path, ':p:h')")
      for i in range(len(runningJobProjectsPaths))
        let isProjectCoveredByNewestSolution = 0
        for j in range(len(projects))
          if runningJobProjectsPaths[i] == projects[j].path
            let isProjectCoveredByNewestSolution = 1
            break
          endif
        endfor
        if !isProjectCoveredByNewestSolution
          let isCompletelyCoveredByNewestSolution = 0
          break
        endif
      endfor
      if isCompletelyCoveredByNewestSolution
        call OmniSharp#StopServer(runningJob)
      endif
    endfor
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
