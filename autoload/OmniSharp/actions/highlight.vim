let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#highlight#Buffer() abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return | endif
  if g:OmniSharp_server_stdio && has('textprop')
    let opts = { 'BufNum':  bufnr('%') }
    call s:StdioHighlight(opts.BufNum)
  else
    " Full semantic highlighting not supported - highlight types instead
    call OmniSharp#actions#highlight_types#Buffer()
  endif
endfunction

function! s:StdioHighlight(bufnr) abort
  let buftick = getbufvar(a:bufnr, 'changedtick')
  let opts = {
  \ 'ResponseHandler': function('s:HighlightRH', [a:bufnr, buftick]),
  \ 'ReplayOnLoad': 1
  \}
  call OmniSharp#stdio#Request('/highlight', opts)
endfunction

function! s:HighlightRH(bufnr, buftick, response) abort
  if !a:response.Success | return | endif
  if getbufvar(a:bufnr, 'changedtick') != a:buftick
    " The buffer has changed while fetching highlights - fetch fresh highlights
    " from the server
    call s:StdioHighlight(a:bufnr)
    return
  endif
  let highlights = get(a:response.Body, 'Highlights', [])
  if !get(s:, 'textPropertiesInitialized', 0)
    let s:groupKinds = get(g:, 'OmniSharp_highlight_groups', {
    \ 'csUserIdentifier': [
    \   'constant name', 'enum member name', 'field name', 'identifier',
    \   'local name', 'parameter name', 'property name', 'static symbol'],
    \ 'csUserInterface': ['interface name'],
    \ 'csUserMethod': ['extension method name', 'method name'],
    \ 'csUserType': ['class name', 'enum name', 'namespace name', 'struct name']
    \})
    " Create the inverse dict for fast lookups
    let s:kindGroups = {}
    for key in keys(s:groupKinds)
      call prop_type_add(key, {'highlight': key, 'combine': 1})
      for kind in s:groupKinds[key]
        let s:kindGroups[kind] = key
      endfor
    endfor
    let s:textPropertiesInitialized = 1
  endif
  let curline = 1
  for hl in highlights
    if curline <= hl.EndLine
      try
        call prop_clear(curline, hl.EndLine, {'bufnr': a:bufnr})
      catch | endtry
      let curline = hl.EndLine + 1
    endif
    if has_key(s:kindGroups, hl.Kind)
      try
        let start_col = s:TranslateVirtColToCol(a:bufnr, hl.StartLine, hl.StartColumn)
        let end_col = s:TranslateVirtColToCol(a:bufnr, hl.EndLine, hl.EndColumn)
        call prop_add(hl.StartLine, start_col, {
        \ 'end_lnum': hl.EndLine,
        \ 'end_col': end_col,
        \ 'type': s:kindGroups[hl.Kind],
        \ 'bufnr': a:bufnr
        \})
      catch
        " E275: This response is for a hidden buffer, and 'nohidden' is set
        " E964: Invalid prop_add col
        " E966: Invalid prop_add lnum
        break
      endtry
    endif
    if get(g:, 'OmniSharp_highlight_debug', 0)
      let hlKind = 'cs' . substitute(hl.Kind, ' ', '_', 'g')
      if !len(prop_type_get(hlKind))
        call prop_type_add(hlKind, {'combine': 1})
      endif
      try
        call prop_add(hl.StartLine, hl.StartColumn, {
        \ 'end_lnum': hl.EndLine,
        \ 'end_col': hl.EndColumn,
        \ 'type': hlKind,
        \ 'bufnr': a:bufnr
        \})
      catch | endtry
    endif
  endfor
endfunction

" The vim prop_add api expects the column to be the byte offset and not
" the character. So for multibyte characters this function returns the
" byte offset for a given character.
function! s:TranslateVirtColToCol(bufnr, lnum, vcol) abort
  let buflines = getbufline(a:bufnr, a:lnum)
  if len(buflines) == 0
    return a:vcol
  endif
  let bufline = buflines[0] . "\n"
  let col = byteidx(bufline, a:vcol)
  if col < 0
    return a:vcol
  endif
  return col
endfunction


function OmniSharp#actions#highlight#EchoKind() abort
  if !g:OmniSharp_server_stdio || !has('textprop')
    echo 'Highlight kinds require text properties, in stdio mode'
  else
    let props = filter(prop_list(line('.')),
    \ 'v:val.col <= col(".") && v:val.col + v:val.length - 1 >= col(".")')
    if len(props)
      for prop in props
        if has_key(s:groupKinds, prop.type)
          echon ' (' . prop.type . ')'
        else
          echon substitute(props[0].type[2:], '_', ' ', 'g')
        endif
      endfor
    else
      echo 'No Kind found'
    endif
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
