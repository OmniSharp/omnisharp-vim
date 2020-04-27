let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#highlight#Buffer() abort
  if bufname('%') ==# '' || OmniSharp#FugitiveCheck() | return | endif
  let opts = { 'BufNum':  bufnr('%') }
  if g:OmniSharp_server_stdio &&
  \ (has('textprop') || exists('*nvim_create_namespace'))
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
      if !has('nvim')
        call prop_type_add(key, {'highlight': key, 'combine': 1})
      endif
      for kind in s:groupKinds[key]
        let s:kindGroups[kind] = key
      endfor
    endfor
    let s:textPropertiesInitialized = 1
  endif
  if has('nvim')
    let nsid = nvim_create_namespace('OmniSharpHighlight')
    call nvim_buf_clear_namespace(a:bufnr, nsid, 0, -1)
  endif
  let curline = 1
  for hl in highlights
    if !has('nvim')
      if curline <= hl.EndLine
        try
          call prop_clear(curline, hl.EndLine, {'bufnr': a:bufnr})
        catch | endtry
        let curline = hl.EndLine + 1
      endif
    endif
    if has_key(s:kindGroups, hl.Kind)
      try
        let start_col = s:GetByteIdx(a:bufnr, hl.StartLine, hl.StartColumn)
        let end_col = s:GetByteIdx(a:bufnr, hl.EndLine, hl.EndColumn)
        if !has('nvim')
          call prop_add(hl.StartLine, start_col, {
          \ 'end_lnum': hl.EndLine,
          \ 'end_col': end_col,
          \ 'type': s:kindGroups[hl.Kind],
          \ 'bufnr': a:bufnr
          \})
        else
          for linenr in range(hl.StartLine - 1, hl.EndLine - 1)
            call nvim_buf_add_highlight(a:bufnr, nsid,
            \ s:kindGroups[hl.Kind],
            \ linenr,
            \ (linenr > hl.StartLine - 1) ? 0 : start_col - 1,
            \ (linenr < hl.EndLine - 1) ? -1 : end_col - 1)
          endfor
        endif
      catch
        " E275: This response is for a hidden buffer, and 'nohidden' is set
        " E964: Invalid prop_add col
        " E966: Invalid prop_add lnum
        break
      endtry
    endif
  endfor
  if get(g:, 'OmniSharp_highlight_debug', 0)
    let s:lastHighlights = highlights
  endif
endfunction

function OmniSharp#actions#highlight#EchoKind() abort
  if !g:OmniSharp_server_stdio
    echo 'Highlight kinds can only be used in stdio mode'
    return
  elseif !has('nvim') && !has('textprop')
    echo 'Highlight kinds requires text properties - your Vim is too old'
    return
  elseif has('nvim') && !exists('*nvim_create_namespace')
    echo 'Highlight kinds requires namespaces - your neovim is too old'
    return
  endif
  let currentHls = 0
  for hl in get(s:, 'lastHighlights', [])
    let hlsl = hl.StartLine
    let hlel = hl.EndLine
    let start_col = s:GetByteIdx(bufnr('%'), hlsl, hl.StartColumn)
    let end_col = s:GetByteIdx(bufnr('%'), hlel, hl.EndColumn)
    if hlsl <= line('.') && hlel >= line('.')
      if (hlsl == hlel && start_col <= col('.') && end_col > col('.')) ||
      \ (hlsl < line('.') && hlel > line('.')) ||
      \ (hlsl < line('.') && end_col > col('.')) ||
      \ (hlel > line('.') && start_col <= col('.'))
        let currentHls += 1
        if has_key(s:kindGroups, hl.Kind)
          echon ' (' . s:kindGroups[hl.Kind] . ')'
        else
          echon hl.Kind
        endif
      endif
    endif
  endfor
  if currentHls == 0
    echo 'No Kind found'
  endif
endfunction

" The vim prop_add and neovim nvim_buf_add_highlight apis expect the column to
" be the byte offset and not the character. So for multibyte characters this
" function returns the byte offset for a given character.
function! s:GetByteIdx(bufnr, lnum, vcol) abort
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

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
