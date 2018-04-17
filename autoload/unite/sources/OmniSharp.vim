let s:save_cpo = &cpoptions
set cpoptions&vim

let s:findcodeactions = {
\   'name': 'OmniSharp/findcodeactions',
\   'description': 'candidates from code actions of OmniSharp',
\   'default_action': 'run',
\   'is_listed': 0,
\ }

function! s:findcodeactions.gather_candidates(args, context) abort
  let s:mode = get(a:args, 0, 'normal')
  let s:actions = get(a:args, 1, [])
  let s:version = get(a:args, 2, 'roslyn')

  if s:version ==# 'v1'
    return map(s:actions, '{
    \   "word": v:val,
    \   "source__OmniSharp_action": v:key,
    \ }')
  else
    let actions = map(copy(s:actions), {i,v -> get(v, 'Name')})
    return map(actions, '{
    \   "word": v:val,
    \   "source__OmniSharp_action": v:val,
    \ }')
  endif
endfunction

let s:findcodeactions_action_table = {
\   'run': {
\     'description': 'run action',
\   }
\ }
function! s:findcodeactions_action_table.run.func(candidate) abort
  let str = a:candidate.source__OmniSharp_action

  if s:version ==# 'v1'
    let action = index(s:actions, str)
    let command = printf('runCodeAction(%s, %d)', string(s:mode), action)
  else
    let action = filter(copy(s:actions), {i,v -> get(v, 'Name') ==# str})[0]
    let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
    let command = printf('runCodeAction(''%s'', ''%s'', ''v2'')', s:mode, command)
  endif
  if !pyeval(command)
    echo 'No action taken'
  endif
endfunction
let s:findcodeactions.action_table = s:findcodeactions_action_table


let s:findsymbols = {
\   'name': 'OmniSharp/findsymbols',
\   'description': 'candidates from C# symbols via OmniSharp',
\   'default_kind': 'jump_list',
\ }
function! s:findsymbols.gather_candidates(args, context) abort
  let quickfixes = get(a:args, 0, [])
  return map(quickfixes, '{
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
  let symbols = pyeval('findTypes()')
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
