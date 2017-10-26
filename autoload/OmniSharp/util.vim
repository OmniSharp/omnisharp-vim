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
  if type(parts) == type('')
    let parts = [parts]
  elseif type(parts) != type([])
    throw 'Unsupported type for joining paths'
  endif

  return join([s:plugin_root_dir] + parts, s:dir_separator)
endfunction

function! OmniSharp#util#get_start_cmd(solution_path) abort
  let solution_path = a:solution_path
  if fnamemodify(solution_path, ':t') ==? s:roslyn_server_files
    let solution_path = fnamemodify(solution_path, ':h')
  endif
  let g:OmniSharp_running_slns += [solution_path]
  let port = exists('b:OmniSharp_port') ? b:OmniSharp_port : g:OmniSharp_port

  let s:server_path = ''
  if !exists('g:OmniSharp_server_path')
    if g:OmniSharp_server_type ==# 'v1'
      let s:server_path = OmniSharp#util#path_join(['server', 'OmniSharp', 'bin', 'Debug', 'OmniSharp.exe'])
    else
      let s:server_extension = has('win32') || has('win32unix') ? '.cmd' : ''
      let s:server_path = OmniSharp#util#path_join(['omnisharp-roslyn', 'artifacts', 'scripts', 'OmniSharp' . s:server_extension])
    endif
  else
    let s:server_path = g:OmniSharp_server_path
  endif

  let port = exists('b:OmniSharp_port') ? b:OmniSharp_port : g:OmniSharp_port
  let command = [
              \ s:server_path,
              \ '-p', port,
              \ '-s', solution_path]

  if g:OmniSharp_server_type !=# 'roslyn'
    let l:config_file = s:resolve_local_config(solution_path)
    if l:config_file !=# ''
      let command = command + ['-config', l:config_file]
    endif
  endif
  if !has('win32') && !has('win32unix') && g:OmniSharp_server_type !=# 'roslyn'
    let command = insert(command, 'mono')
  endif

  return command
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: shiftwidth=2
