if !(has('python') || has('python3'))
  finish
endif

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:alive_cache = get(s:, 'alive_cache', [])
let s:pycmd = has('python3') ? 'python3' : 'python'
let s:pyfile = has('python3') ? 'py3file' : 'pyfile'
let g:OmniSharp_py_err = {}
let g:OmniSharp_python_path = OmniSharp#util#PathJoin(['python'])

" Default map of solution files and directories to ports.
" Preserve backwards compatibility with older version g:OmniSharp_sln_ports
let g:OmniSharp_server_ports = get(g:, 'OmniSharp_server_ports', get(g:, 'OmniSharp_sln_ports', {}))
let s:initial_server_ports = get(s:, 'initial_server_ports',
\ copy(g:OmniSharp_server_ports))

if has('python3') && exists('*py3eval')
  let s:pyeval = function('py3eval')
elseif exists('*pyeval')
  let s:pyeval = function('pyeval')
else
  exec s:pycmd 'import json, vim'
  function! s:pyeval(e)
    exec s:pycmd 'vim.command("return " + json.dumps(eval(vim.eval("a:e"))))'
  endfunction
endif

function! OmniSharp#py#Bootstrap() abort
  if exists('s:bootstrap_complete') | return | endif
  exec s:pycmd "sys.path.append(r'" . g:OmniSharp_python_path . "')"
  exec s:pyfile fnameescape(OmniSharp#util#PathJoin(['python', 'bootstrap.py']))
  let s:bootstrap_complete = 1
endfunction

function! OmniSharp#py#CheckAlive(sln_or_dir) abort
  if index(s:alive_cache, a:sln_or_dir) >= 0 | return 1 | endif
  let alive = OmniSharp#py#Eval('checkAliveStatus()')
  if OmniSharp#py#CheckForError() | return 0 | endif
  if alive
    " Cache the alive status so subsequent calls are faster
    call add(s:alive_cache, a:sln_or_dir)
  endif
  return alive
endfunction

function! OmniSharp#py#CheckForError(...) abort
  let should_print = a:0 ? a:1 : 1
  if !empty(g:OmniSharp_py_err)
    if should_print
      call OmniSharp#util#EchoErr(
      \ printf('%s: %s', g:OmniSharp_py_err.code, g:OmniSharp_py_err.msg))
    endif
    " If we got a connection error when hitting the server, then the server may
    " not be running anymore and we should bust the 'alive' cache
    if g:OmniSharp_py_err.code ==? 'CONNECTION'
      call OmniSharp#py#Uncache()
    endif
    return 1
  endif
  return 0
endfunction

function! OmniSharp#py#FindRunningServer(solution_files) abort
  let running_slns = []
  if len(g:OmniSharp_server_ports)
    " g:OmniSharp_server_ports has been set; auto-select one of the
    " specified servers
    for solutionfile in a:solution_files
      if has_key(g:OmniSharp_server_ports, solutionfile)
        call add(running_slns, solutionfile)
      endif
    endfor
  endif
  return running_slns
endfunction

function! OmniSharp#py#GetPort(...) abort
  if exists('g:OmniSharp_port')
    return g:OmniSharp_port
  endif

  let sln_or_dir = a:0 ? a:1 : OmniSharp#FindSolutionOrDir()
  if empty(sln_or_dir)
    return 0
  endif

  " If we're already running this solution, choose the port we're running on
  if has_key(g:OmniSharp_server_ports, sln_or_dir)
    return g:OmniSharp_server_ports[sln_or_dir]
  endif

  " Otherwise, find a free port and use that for this solution
  let port = OmniSharp#py#Eval('find_free_port()')
  if OmniSharp#py#CheckForError() | return 0 | endif
  let g:OmniSharp_server_ports[sln_or_dir] = port
  return port
endfunction


function! OmniSharp#py#Eval(cmd) abort
  return s:pyeval(a:cmd)
endfunction

function! OmniSharp#py#IsServerPortHardcoded(sln_or_dir) abort
  if exists('g:OmniSharp_port') | return 1 | endif
  return has_key(s:initial_server_ports, a:sln_or_dir)
endfunction

" Remove a server from the alive_cache
function! OmniSharp#py#Uncache(...) abort
  let sln_or_dir = a:0 ? a:1 : OmniSharp#FindSolutionOrDir(0)
  let idx = index(s:alive_cache, sln_or_dir)
  if idx != -1
    call remove(s:alive_cache, idx)
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
