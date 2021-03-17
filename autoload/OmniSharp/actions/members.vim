let s:save_cpo = &cpoptions
set cpoptions&vim

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the list of found locations
" of members.
" This is done instead of showing a quick-fix.
function! OmniSharp#actions#members#Find(...) abort
  if a:0 && a:1 isnot 0
    let Callback = a:1
  else
    let Callback = function('s:CBFindMembers')
  endif

  if g:OmniSharp_server_stdio
    call s:StdioFind(Callback)
  else
    let locs = OmniSharp#py#Eval('findMembers()')
    if OmniSharp#py#CheckForError() | return | endif
    return Callback(locs)
  endif
endfunction

function! s:StdioFind(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback])
  \}
  call OmniSharp#stdio#Request('/v2/codestructure', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(s:ParseCodeStructure(a:response.Body))
endfunction

function! s:ParseCodeStructure(responseBody) abort
  let locations = []
  let filename = expand('%:p')
  for element in a:responseBody.Elements
    call s:ParseCodeStructureItemRec(element, filename, locations)
  endfor
  return locations
endfunction

function! s:ParseCodeStructureItemRec(item, filename, locations) abort
  call add(a:locations, s:ParseCodeStructureItem(a:item, a:filename))
  let children = get(a:item, 'Children', [])
  if type(children) == type([])
    for child in children
      call s:ParseCodeStructureItemRec(child, a:filename, a:locations)
    endfor
  endif
endfunction

function! s:ParseCodeStructureItem(item, filename) abort
  return {
    \ 'filename': a:filename,
    \ 'lnum':     a:item.Ranges.name.Start.Line,
    \ 'col':      a:item.Ranges.name.Start.Column,
    \ 'end_lnum': a:item.Ranges.name.End.Line,
    \ 'end_col':  a:item.Ranges.name.End.Column - 1,
    \ 'text':     s:ComputeItemSignature(a:item),
    \ 'vcol': 1
  \}
endfunction

function! s:ComputeItemSignature(item) abort
  if type(a:item.Properties) != type({})
    return get(a:item, 'Kind', '') . ' ' . a:item.DisplayName
  endif
  let line   = a:item.Ranges.name.Start.Line
  let endcol = a:item.Ranges.name.Start.Column - 2
  let textBeforeDisplayName = substitute(getline(line)[:endcol], '^\s*', '', '')
  if textBeforeDisplayName !~# '^\(private\|internal\|protected\|public\)'
    let textBeforeDisplayName = a:item.Properties.accessibility . ' ' . textBeforeDisplayName
  endif
  return ReduceToOneCharacter(textBeforeDisplayName) . a:item.DisplayName
endfunction

let s:SingleCharacterSymbolByAccessModifier = {
 \ 'public': '+',
 \ 'private': '-',
 \ 'internal': '&',
 \ 'protected': '|'
\}

function! ReduceToOneCharacter(textBeforeDisplayName) abort
  let accessModifier = matchlist(a:textBeforeDisplayName, '\w\+')[0]
  let accessModifierLen = len(accessModifier)
  return s:SingleCharacterSymbolByAccessModifier[accessModifier] . a:textBeforeDisplayName[accessModifierLen:]
endfunction

function! s:CBFindMembers(locations) abort
  let numMembers = len(a:locations)
  if numMembers > 0
    call OmniSharp#locations#SetQuickfixWithVerticalAlign(a:locations, 'Members')
  endif
  return numMembers
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
