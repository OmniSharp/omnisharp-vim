let s:save_cpo = &cpoptions
set cpoptions&vim

let s:findcodeactions = {
\   'name': 'omnisharp/findcodeactions',
\   'description': 'candidates from code actions of OmniSharp',
\   'default_action': 'run',
\   'is_listed': 0,
\ }

function! s:findcodeactions.gather_candidates(args, context) abort
  let mode = get(a:args, 0, 'normal')
  let actions = pyeval(printf('getCodeActions(%s)', string(mode)))
  if empty(actions)
    call unite#print_source_message('No code actions found', s:findcodeactions.name)
  endif
  return map(actions, '{
  \   "word": v:val,
  \   "source__omnisharp_mode": mode,
  \   "source__omnisharp_action": v:key,
  \ }')
endfunction

let s:findcodeactions_action_table = {
\   'run': {
\     'description': 'run action',
\   }
\ }
function! s:findcodeactions_action_table.run.func(candidate) abort
  let mode = a:candidate.source__omnisharp_mode
  let action = a:candidate.source__omnisharp_action
  call pyeval(printf('runCodeAction(%s, %d)', string(mode), action))
endfunction
let s:findcodeactions.action_table = s:findcodeactions_action_table


let s:findsymbols = {
\   'name': 'omnisharp/findsymbols',
\   'description': 'candidates from C# symbols via OmniSharp',
\   'default_kind': 'jump_list',
\ }
function! s:findsymbols.gather_candidates(args, context) abort
  if !OmniSharp#ServerIsRunning()
    return []
  endif
  let symbols = pyeval('findSymbols()')
  return map(symbols, '{
  \   "word": get(split(v:val.text, "\t"), 0),
  \   "abbr": v:val.text,
  \   "action__path": v:val.filename,
  \   "action__line": v:val.lnum,
  \   "action__col": v:val.col,
  \ }')
endfunction


function! unite#sources#omnisharp#define()
  return [s:findcodeactions, s:findsymbols]
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo
