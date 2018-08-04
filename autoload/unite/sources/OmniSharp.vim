if !(has('python') || has('python3'))
  finish
endif

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

  let actions = map(copy(s:actions), {i,v -> get(v, 'Name')})
  return map(actions, '{
  \   "word": v:val,
  \   "source__OmniSharp_action": v:val,
  \ }')
endfunction

let s:findcodeactions_action_table = {
\   'run': {
\     'description': 'run action',
\   }
\ }
function! s:findcodeactions_action_table.run.func(candidate) abort
  let str = a:candidate.source__OmniSharp_action

  let action = filter(copy(s:actions), {i,v -> get(v, 'Name') ==# str})[0]
  let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
  let command = printf('runCodeAction(''%s'', ''%s'')', s:mode, command)
  let result = OmniSharp#py#eval(command)
  if OmniSharp#CheckPyError() | return | endif
  if !result
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


function! unite#sources#OmniSharp#define() abort
  return [s:findcodeactions, s:findsymbols]
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
