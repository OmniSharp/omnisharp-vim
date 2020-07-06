let s:save_cpo = &cpoptions
set cpoptions&vim

" This is the older highlighting mechanism, where all symbols are fetched from
" the OmniSharp-roslyn, and then highlights are created using matchadd().
"
" The HTTP server with its python interface can only use this type of
" highlighting, as can older versions of vim without text properties (vim 8) or
" namespaces (neovim).
"
" Use OmniSharp#actions#highlight#Buffer() for full semantic highlighting.
function! OmniSharp#actions#highlight_types#Buffer() abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return | endif
  call OmniSharp#actions#highlight_types#Initialise()
  let bufnr = bufnr('%')
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBHighlightBuffer', [bufnr])
    call s:StdioFindHighlightTypes(bufnr, Callback)
  else
    if !OmniSharp#IsServerRunning() | return | endif
    let hltypes = OmniSharp#py#Eval('findHighlightTypes()')
    if OmniSharp#py#CheckForError() | return | endif
    call s:CBHighlightBuffer(bufnr, hltypes)
  endif
endfunction

function! s:StdioFindHighlightTypes(bufnr, Callback) abort
  let bufferLines = getline(1, '$')
  let opts = {
  \ 'ResponseHandler': function('s:FindHighlightTypesRH', [a:Callback, bufferLines]),
  \ 'BufNum': a:bufnr,
  \ 'ReplayOnLoad': 1
  \}
  call OmniSharp#stdio#Request('/highlight', opts)
endfunction

function! s:FindHighlightTypesRH(Callback, bufferLines, response) abort
  if !a:response.Success | return | endif
  let highlights = get(a:response.Body, 'Highlights', [])
  let identifierKinds = ['constant name', 'enum member name', 'field name',
  \ 'identifier', 'local name', 'parameter name', 'property name',
  \ 'static symbol']
  let interfaceKinds = ['interface name']
  let methodKinds = ['extension method name', 'method name']
  let typeKinds = ['class name', 'enum name', 'namespace name', 'struct name']
  let types = []
  for hl in highlights
    let lnum = hl.StartLine - 1
    if lnum >= len(a:bufferLines)
      " An error has occurred with invalid line endings - perhaps a combination
      " of unix and dos line endings?
      call a:Callback({'error': 'Invalid buffer - check line endings'})
      return
    endif
    let line = a:bufferLines[lnum]
    call add(types, {
    \ 'kind': hl.Kind,
    \ 'name': line[hl.StartColumn - 1 : hl.EndColumn - 2]
    \})
  endfor

  let hltypes = {
  \ 'identifiers': map(filter(copy(types), 'index(identifierKinds, v:val.kind) >= 0'), 'v:val.name'),
  \ 'interfaces': map(filter(copy(types), 'index(interfaceKinds, v:val.kind) >= 0'), 'v:val.name'),
  \ 'methods': map(filter(copy(types), 'index(methodKinds, v:val.kind) >= 0'), 'v:val.name'),
  \ 'types': map(filter(copy(types), 'index(typeKinds, v:val.kind) >= 0'), 'v:val.name')
  \}

  call a:Callback(hltypes)
endfunction

function! s:CBHighlightBuffer(bufnr, hltypes) abort
  if has_key(a:hltypes, 'error')
    echohl WarningMsg | echom a:hltypes.error | echohl None
    return
  endif
  " matchadd() only works in the current window/buffer, so if the user has
  " navigated away from the buffer where the request was made, this response can
  " not be applied
  if bufnr('%') != a:bufnr | return | endif

  let b:OmniSharp_hl_matches = get(b:, 'OmniSharp_hl_matches', [])

  " Clear any matches - highlights with :syn keyword {option} names which cannot
  " be created with :syn keyword
  for l:matchid in b:OmniSharp_hl_matches
    try
      call matchdelete(l:matchid)
    catch | endtry
  endfor
  let b:OmniSharp_hl_matches = []

  call s:Highlight(a:hltypes.identifiers, 'csUserIdentifier')
  call s:Highlight(a:hltypes.interfaces, 'csUserInterface')
  call s:Highlight(a:hltypes.methods, 'csUserMethod')
  call s:Highlight(a:hltypes.types, 'csUserType')

  silent call s:ClearHighlight('csNewType')
  syntax region csNewType start="@\@1<!\<new\>"hs=s+4 end="[;\n{(<\[]"me=e-1
  \ contains=csNew,csUserType,csUserIdentifier
endfunction

function! s:ClearHighlight(groupname)
  try
    execute 'syntax clear' a:groupname
  catch | endtry
endfunction

function! s:Highlight(types, group) abort
  silent call s:ClearHighlight(a:group)
  if empty(a:types)
    return
  endif
  let l:types = uniq(sort(a:types))

  " Cannot use vim syntax options as keywords, so remove types with these
  " names. See :h :syn-keyword /Note
  let l:opts = split('cchar conceal concealends contained containedin ' .
  \ 'contains display extend fold nextgroup oneline skipempty skipnl ' .
  \ 'skipwhite transparent')

  " Create a :syn-match for each type with an option name.
  let l:illegal = filter(copy(l:types), {i,v -> index(l:opts, v, 0, 1) >= 0})
  for l:ill in l:illegal
    let matchid = matchadd(a:group, '\<' . l:ill . '\>')
    call add(b:OmniSharp_hl_matches, matchid)
  endfor

  call filter(l:types, {i,v -> index(l:opts, v, 0, 1) < 0})

  if len(l:types)
    execute 'syntax keyword' a:group join(l:types)
  endif
endfunction

function! OmniSharp#actions#highlight_types#Initialise() abort
  if get(s:, 'highlightsInitialized') | return | endif
  let s:highlightsInitialized = 1
  highlight default link csUserIdentifier Identifier
  highlight default link csUserInterface Include
  highlight default link csUserMethod Function
  highlight default link csUserType Type
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
