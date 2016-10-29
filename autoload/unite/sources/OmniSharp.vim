let s:save_cpo = &cpoptions
set cpoptions&vim
if exists('*py3eval')
  let s:pyeval = function('py3eval')
elseif exists('*pyeval')
  let s:pyeval = function('pyeval')
else
  exec s:pycmd ' import json, vim'
  function! s:pyeval(e)
    exec s:pycmd ' vim.command("return " + json.dumps(eval(vim.eval("a:e"))))'
  endfunction
endif

let s:pycmd = has('python3') ? 'python3' : 'python'
let s:pyfile = has('python3') ? 'py3file' : 'pyfile'
if exists('*py3eval')
  let s:pyeval = function('py3eval')
elseif exists('*pyeval')
  let s:pyeval = function('pyeval')
else
  exec s:pycmd 'import json, vim'
  function! s:pyeval(e)
    exec s:pycmd 'vim.command("return " + json.dumps(eval(vim.eval("a:e"))))'
  endfunction
endif

let s:findcodeactions = {
\   'name': 'OmniSharp/findcodeactions',
\   'description': 'candidates from code actions of OmniSharp',
\   'default_action': 'run',
\   'is_listed': 0,
\ }

function! s:findcodeactions.gather_candidates(args, context) abort
  let mode = get(a:args, 0, 'normal')
  let actions = s:pyeval(printf('getCodeActions(%s)', string(mode)))
  if empty(actions)
    call unite#print_source_message('No code actions found', s:findcodeactions.name)
  endif
  return map(actions, '{
  \   "word": v:val,
  \   "source__OmniSharp_mode": mode,
  \   "source__OmniSharp_action": v:key,
  \ }')
endfunction

let s:findcodeactions_action_table = {
\   'run': {
\     'description': 'run action',
\   }
\ }
function! s:findcodeactions_action_table.run.func(candidate) abort
  let mode = a:candidate.source__OmniSharp_mode
  let action = a:candidate.source__OmniSharp_action
  call s:pyeval(printf('runCodeAction(%s, %d)', string(mode), action))
endfunction
let s:findcodeactions.action_table = s:findcodeactions_action_table


let s:findsymbols = {
\   'name': 'OmniSharp/findsymbols',
\   'description': 'candidates from C# symbols via OmniSharp',
\   'default_kind': 'jump_list',
\ }
function! s:findsymbols.gather_candidates(args, context) abort
  if !OmniSharp#ServerIsRunning()
    return []
  endif
  let symbols = s:pyeval('findSymbols()')
  return map(symbols, '{
  \   "word": get(split(v:val.text, "\t"), 0),
  \   "abbr": v:val.text,
  \   "action__path": v:val.filename,
  \   "action__line": v:val.lnum,
  \   "action__col": v:val.col,
  \ }')
endfunction


let s:findtype = {
\   'name': 'OmniSharp/findtype',
\   'description': 'candidates from C# types via OmniSharp',
\   'default_kind': 'jump_list',
\ }
function! s:findtype.gather_candidates(args, context) abort
  if !OmniSharp#ServerIsRunning()
    return []
  endif
  let symbols = s:pyeval('findTypes()')
  return map(symbols, '{
  \   "word": get(split(v:val.text, "\t"), 0),
  \   "abbr": v:val.text,
  \   "action__path": v:val.filename,
  \   "action__line": v:val.lnum,
  \   "action__col": v:val.col,
  \ }')
endfunction


function! unite#sources#OmniSharp#define() abort
  return [s:findcodeactions, s:findsymbols, s:findtype]
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
