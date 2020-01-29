let s:save_cpo = &cpoptions
set cpoptions&vim

let s:dir_separator = fnamemodify('.', ':p')[-1 :]
let s:roslyn_server_files = 'project.json'
let s:plugin_root_dir = expand('<sfile>:p:h:h:h')

function! s:is_msys() abort
  if get(s:, 'is_msys_checked', 0)
    return s:is_msys_val
  endif
  let s:is_msys_val = strlen(system('grep MSYS_NT /proc/version')) > 0
  \ || strlen(system('grep MINGW /proc/version')) > 0
  let s:is_msys_checked = 1
  return s:is_msys_val
endfunction

function! s:is_cygwin() abort
  if get(s:, 'is_cygwin_checked', 0)
    return s:is_cygwin_val
  endif
  let s:is_cygwin_val = has('win32unix')
  let s:is_cygwin_checked = 1
  return s:is_cygwin_val
endfunction

function! s:is_wsl() abort
  if get(s:, 'is_wsl_checked', 0)
    return s:is_wsl_val
  endif
  let s:is_wsl_val = strlen(system('grep Microsoft /proc/version')) > 0
  let s:is_wsl_checked = 1
  return s:is_wsl_val
endfunction

function! OmniSharp#util#CheckCapabilities() abort
  if exists('s:capable') | return s:capable | endif

  let s:capable = 1

  if g:OmniSharp_server_stdio
    if has('nvim')
      if !(exists('*jobstart') && has('lambda'))
        call OmniSharp#util#EchoErr('Error: A newer version of neovim is required for stdio')
        let s:capable = 0
      endif
    else
      if !(has('job') && has('channel') && has('lambda'))
        call OmniSharp#util#EchoErr('Error: A newer version of Vim is required for stdio')
        let s:capable = 0
      endif
    endif
  else
    if !(has('python') || has('python3'))
      call OmniSharp#util#EchoErr('Error: OmniSharp requires Vim compiled with +python or +python3')
      let s:capable = 0
    endif
  endif

  if !s:capable
    " Clear BufEnter and InsertLeave autocmds
    silent! autocmd! OmniSharp#HighlightTypes
    " Clear plugin integration autocmds
    silent! autocmd! OmniSharp#Integrations
  endif

  return s:capable
endfunction

" :echoerr will throw if inside a try conditional, or function labeled 'abort'
" This function will do the same thing without throwing
function! OmniSharp#util#EchoErr(msg)
  let v:errmsg = a:msg
  echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function! OmniSharp#util#TranslatePathForClient(filename) abort
  let filename = a:filename
  if g:OmniSharp_translate_cygwin_wsl && (s:is_wsl() || s:is_msys() || s:is_cygwin())
    if s:is_msys()
      let prefix = '/'
    elseif s:is_cygwin()
      let prefix = '/cygdrive/'
    else
      let prefix = '/mnt/'
    endif
    let filename = substitute(filename, '^\([a-zA-Z]\):\\', prefix . '\l\1/', '')
    let filename = substitute(filename, '\\', '/', 'g')
  endif

  " Check if the file is a metadatafile. If it is, map it to the
  " correct temp file on disk
  if filename =~# '\$metadata\$'
    let filename = g:OmniSharp_temp_dir . '/' . fnamemodify(filename, ':t')
  endif
  return fnamemodify(filename, ':.')
endfunction

function! OmniSharp#util#TranslatePathForServer(filename) abort
  let filename = a:filename
  if g:OmniSharp_translate_cygwin_wsl && (s:is_wsl() || s:is_msys() || s:is_cygwin())
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
    let filename = substitute(filename, prefix . '\([a-zA-Z]\)/', '\u\1:\\', '')
    let filename = substitute(filename, '/', '\\', 'g')
  endif
  return filename
endfunction

function! OmniSharp#util#GetStartCmd(solution_file) abort
  let solution_path = a:solution_file
  if fnamemodify(solution_path, ':t') ==? s:roslyn_server_files
    let solution_path = fnamemodify(solution_path, ':h')
  endif

  let solution_path = OmniSharp#util#TranslatePathForServer(solution_path)

  if exists('g:OmniSharp_server_path')
    let s:server_path = g:OmniSharp_server_path
  else
    let parts = [g:OmniSharp_server_install]
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
        return
      endif
    endif
  endif

  let command = [ s:server_path ]
  if !g:OmniSharp_server_stdio
    let command += [ '-p', OmniSharp#GetPort(a:solution_file) ]
  endif
  let command += [ '-s', solution_path ]

  if !has('win32') && !s:is_cygwin() && g:OmniSharp_server_use_mono
    let command = insert(command, 'mono')
  endif

  " Enforce OmniSharp server use utf-8 encoding.
  let command += [ '-e', 'utf-8' ]

  return command
endfunction

function! OmniSharp#util#PathJoin(parts) abort
  if type(a:parts) == type('')
    let parts = [a:parts]
  elseif type(a:parts) == type([])
    let parts = a:parts
  else
    throw 'Unsupported type for joining paths'
  endif
  return join([s:plugin_root_dir] + parts, s:dir_separator)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
