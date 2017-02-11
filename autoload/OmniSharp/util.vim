let s:save_cpo = &cpoptions
set cpoptions&vim

let s:dir_separator = fnamemodify('.', ':p')[-1 :]
"let s:dir_separator = has('win32') ? '\' : '/'
let s:roslyn_server_files = 'project.json'
let s:plugin_root_dir = expand('<sfile>:p:h:h:h')
let g:OmniSharp_running_slns = []

function! s:resolve_local_config(solution_path) abort
  let configPath = fnamemodify(a:solution_path, ':p:h')
  \ . s:dir_separator
  \ . g:OmniSharp_server_config_name

  if filereadable(configPath)
    return configPath
  endif
  return ''
endfunction

function! OmniSharp#util#path_join(parts) abort
  let parts = a:parts
  if type(parts) == type("")
    let parts = [parts]
  elseif type(parts) != type([])
    throw "Unsupported type for joining paths"
  endif

  return join([s:plugin_root_dir] + parts, s:dir_separator)
endfunction

function! OmniSharp#util#get_start_cmd(solution_path) abort
  let solutionPath = a:solution_path
  if fnamemodify(solutionPath, ':t') ==? s:roslyn_server_files
    let solutionPath = fnamemodify(solutionPath, ':h')
  endif

  let cmd = g:OmniSharp_server_path
  if s:is_vimproc
    let cmd = substitute(cmd, '\\', '/', 'g')
    let solutionPath = substitute(solutionPath, '\\', '/', 'g')
  elseif has('win32') && &shell =~ 'cmd'
    let cmd = substitute(cmd, '/', '\\', 'g')
  endif

  let g:OmniSharp_running_slns += [solutionPath]
  let port = exists('b:OmniSharp_port') ? b:OmniSharp_port : g:OmniSharp_port
  let command = [
              \ cmd,
              \ '-p', port,
              \ '-s', solutionPath]

  if g:OmniSharp_server_type !=# 'roslyn'
    let l:config_file = OmniSharp#ResolveLocalConfig(solutionPath)
    if l:config_file !=# ''
      let command = command + ['-config', l:config_file]
    endif
  endif
  if !has('win32') && !has('win32unix') && g:OmniSharp_server_type !=# 'roslyn'
    let command = insert(command, "mono")
  endif

  return command
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: shiftwidth=2
