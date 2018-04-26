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

function! s:is_msys() abort
  return strlen(system('grep MSYS_NT /proc/version')) > 0
endfunction

function! s:is_cygwin() abort
  return has('win32unix')
endfunction

function! s:is_wsl() abort
  return strlen(system('grep Microsoft /proc/version')) > 0
endfunction

function! OmniSharp#util#path_join(parts) abort
  if type(a:parts) == type('')
    let parts = [a:parts]
  elseif type(a:parts) == type([])
    let parts = a:parts
  else
    throw 'Unsupported type for joining paths'
  endif
  return join([s:plugin_root_dir] + parts, s:dir_separator)
endfunction

function! OmniSharp#util#get_start_cmd(solution_path) abort
  let solution_path = a:solution_path
  if fnamemodify(solution_path, ':t') ==? s:roslyn_server_files
    let solution_path = fnamemodify(solution_path, ':h')
  endif

  if g:OmniSharp_translate_cygwin_wsl == 1 && (s:is_msys() || s:is_cygwin() || s:is_wsl())
    " Future releases of WSL will have a wslpath tool, similar to cygpath - when
    " this becomes standard then this block can be replaced with a call to
    " wslpath/cygpath
    if s:is_msys()
      let prefix = '^/'
    elseif s:is_cygwin()
      let prefix = '^/cygdrive/'
    else
      let prefix = '^/mnt/'
    endif
    let solution_path = substitute(solution_path, prefix.'\([a-zA-Z]\)/', '\u\1:\\', '')
    let solution_path = substitute(solution_path, '/', '\\', 'g')
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

  if g:OmniSharp_server_type ==# 'v1'
    let l:config_file = s:resolve_local_config(solution_path)
    if l:config_file !=# ''
      let command = command + ['-config', l:config_file]
    endif
  endif
  if !has('win32') && !has('win32unix') && (g:OmniSharp_server_use_mono || g:OmniSharp_server_type ==# 'v1')
    let command = insert(command, 'mono')
  endif

  return command
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim: shiftwidth=2
