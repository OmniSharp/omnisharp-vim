let s:save_cpo = &cpoptions
set cpoptions&vim

let s:dir_separator = fnamemodify('.', ':p')[-1 :]
let s:roslyn_server_files = 'project.json'
let s:plugin_root_dir = expand('<sfile>:p:h:h:h')

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

" :echoerr will throw if inside a try conditional, or function labeled 'abort'
" This function will do the same thing without throwing
function! OmniSharp#util#EchoErr(msg)
  let v:errmsg = a:msg
  echohl ErrorMsg | echomsg a:msg | echohl None
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

function! OmniSharp#util#get_start_cmd(solution_file) abort
  let solution_path = a:solution_file
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

  let port = OmniSharp#GetPort(a:solution_file)

  let s:server_path = ''
  if !exists('g:OmniSharp_server_path')
    let parts = [expand('$HOME'), '.omnisharp', 'omnisharp-roslyn']
    if has('win32') || s:is_cygwin() || g:OmniSharp_server_use_mono
      let parts += ['OmniSharp.exe']
    else
      let parts += ['run']
    endif
    let s:server_path = join(parts, s:dir_separator)
    if !executable(s:server_path)
      if confirm('The OmniSharp server does not appear to be installed. Would you like to install it?', "&Yes\n&No", 2) == 1
        call OmniSharp#Install()
      else
        redraw
      endif
    endif
  else
    let s:server_path = g:OmniSharp_server_path
  endif

  let command = [
              \ s:server_path,
              \ '-p', port,
              \ '-s', solution_path]

  if !has('win32') && !s:is_cygwin() && g:OmniSharp_server_use_mono
    let command = insert(command, 'mono')
  endif

  return command
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
