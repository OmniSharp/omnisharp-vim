if !(has('python') || has('python3'))
  finish
endif

let s:pycmd = has('python3') ? 'python3' : 'python'
let s:pyfile = has('python3') ? 'py3file' : 'pyfile'
let g:OmniSharp_python_path = OmniSharp#util#path_join(['python'])

let s:save_cpo = &cpoptions
set cpoptions&vim

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

function! OmniSharp#py#load(filename)
  call OmniSharp#py#bootstrap()
  exec s:pyfile fnameescape(OmniSharp#util#path_join(['python', 'omnisharp', a:filename]))
endfunction

function! OmniSharp#py#bootstrap()
  if exists('s:bootstrap_complete')
    return
  endif
  exec s:pycmd "sys.path.append(r'" . g:OmniSharp_python_path . "')"
  exec s:pyfile fnameescape(OmniSharp#util#path_join(['python', 'bootstrap.py']))
  let s:bootstrap_complete = 1
endfunction

function! OmniSharp#py#eval(cmd) abort
  return s:pyeval(a:cmd)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
