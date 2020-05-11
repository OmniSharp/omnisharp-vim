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
  call OmniSharp#stdio#Request('/v2/highlight', opts)
endfunction

function! s:HighlightRH(bufnr, buftick, response) abort
  if !a:response.Success | return | endif
  if getbufvar(a:bufnr, 'changedtick') != a:buftick
    " The buffer has changed while fetching highlights - fetch fresh highlights
    " from the server
    call s:StdioHighlight(a:bufnr)
    return
  endif
  call s:InitialiseHighlights()
  if has('nvim')
    let nsid = nvim_create_namespace('OmniSharpHighlight')
    call nvim_buf_clear_namespace(a:bufnr, nsid, 0, -1)
  endif
  let spans = get(a:response.Body, 'Spans', [])
  let curline = 1
  for span in spans
    if !has('nvim')
      if curline <= span.EndLine
        try
          call prop_clear(curline, span.EndLine, {'bufnr': a:bufnr})
        catch | endtry
        let curline = span.EndLine + 1
      endif
    endif
    let shc = s:SemanticHighlightClassification[span.Type]
    if type(shc.highlight) == v:t_string
      try
        let start_col = s:GetByteIdx(a:bufnr, span.StartLine, span.StartColumn)
        let end_col = s:GetByteIdx(a:bufnr, span.EndLine, span.EndColumn)
        if !has('nvim')
          call prop_add(span.StartLine, start_col, {
          \ 'end_lnum': span.EndLine,
          \ 'end_col': end_col,
          \ 'type': 'OSHighlight' . shc.highlight,
          \ 'bufnr': a:bufnr
          \})
        else
          for linenr in range(span.StartLine - 1, span.EndLine - 1)
            call nvim_buf_add_highlight(a:bufnr, nsid,
            \ shc.highlight,
            \ linenr,
            \ (linenr > span.StartLine - 1) ? 0 : start_col - 1,
            \ (linenr < span.EndLine - 1) ? -1 : end_col - 1)
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
  let s:lastSpans = spans
endfunction

function! s:InitialiseHighlights() abort
  if get(s:, 'highlightsInitialized', 0) | return | endif
  let s:highlightsInitialized = 1

  if !has('nvim')
    let groups = copy(s:SemanticHighlightClassification)
    let groups = map(groups, 'v:val.highlight')
    let groups = filter(groups, 'type(v:val) == v:t_string')
    let groups = uniq(sort(groups))
    for group in groups
      call prop_type_add('OSHighlight' . group, {'highlight': group, 'combine': 1})
    endfor
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
  let currentSpans = 0
  for span in get(s:, 'lastSpans', [])
    let startLine = span.StartLine
    let endLine = span.EndLine
    let startCol = s:GetByteIdx(bufnr('%'), startLine, span.StartColumn)
    let endCol = s:GetByteIdx(bufnr('%'), endLine, span.EndColumn)
    if startLine <= line('.') && endLine >= line('.')
      if (startLine == endLine && startCol <= col('.') && endCol > col('.'))
      \ || (startLine < line('.') && endLine > line('.'))
      \ || (startLine < line('.') && endCol > col('.'))
      \ || (endLine > line('.') && startCol <= col('.'))
        let currentSpans += 1
        let shc = s:SemanticHighlightClassification[span.Type]
        if type(shc.highlight) == v:t_string
          echon shc.name . ' ('
          execute 'echohl' shc.highlight
          echon shc.highlight
          echohl None
          echon ')'
        else
          echo shc.name
        endif
      endif
    endif
  endfor
  if currentSpans == 0
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

" All classifications from Roslyn's ClassificationTypeNames
" https://github.com/dotnet/roslyn/blob/master/src/Workspaces/Core/Portable/Classification/ClassificationTypeNames.cs
" Keep in sync with omnisharp-roslyn's SemanticHighlightClassification
let s:SemanticHighlightClassification = [
\ { 'name': 'Comment',                            'highlight': 0 },
\ { 'name': 'ExcludedCode',                       'highlight': 0 },
\ { 'name': 'Identifier',                         'highlight': 'Identifier' },
\ { 'name': 'Keyword',                            'highlight': 0 },
\ { 'name': 'ControlKeyword',                     'highlight': 0 },
\ { 'name': 'NumericLiteral',                     'highlight': 0 },
\ { 'name': 'Operator',                           'highlight': 0 },
\ { 'name': 'OperatorOverloaded',                 'highlight': 0 },
\ { 'name': 'PreprocessorKeyword',                'highlight': 0 },
\ { 'name': 'StringLiteral',                      'highlight': 0 },
\ { 'name': 'WhiteSpace',                         'highlight': 0 },
\ { 'name': 'Text',                               'highlight': 0 },
\ { 'name': 'StaticSymbol',                       'highlight': 'Identifier' },
\ { 'name': 'PreprocessorText',                   'highlight': 0 },
\ { 'name': 'Punctuation',                        'highlight': 0 },
\ { 'name': 'VerbatimStringLiteral',              'highlight': 0 },
\ { 'name': 'StringEscapeCharacter',              'highlight': 0 },
\ { 'name': 'ClassName',                          'highlight': 'Identifier' },
\ { 'name': 'DelegateName',                       'highlight': 'Identifier' },
\ { 'name': 'EnumName',                           'highlight': 'Identifier' },
\ { 'name': 'InterfaceName',                      'highlight': 'Include' },
\ { 'name': 'ModuleName',                         'highlight': 0 },
\ { 'name': 'StructName',                         'highlight': 'Identifier' },
\ { 'name': 'TypeParameterName',                  'highlight': 'Type' },
\ { 'name': 'FieldName',                          'highlight': 'Identifier' },
\ { 'name': 'EnumMemberName',                     'highlight': 'Identifier' },
\ { 'name': 'ConstantName',                       'highlight': 'Identifier' },
\ { 'name': 'LocalName',                          'highlight': 'Identifier' },
\ { 'name': 'ParameterName',                      'highlight': 'Identifier' },
\ { 'name': 'MethodName',                         'highlight': 'Function' },
\ { 'name': 'ExtensionMethodName',                'highlight': 'Function' },
\ { 'name': 'PropertyName',                       'highlight': 'Identifier' },
\ { 'name': 'EventName',                          'highlight': 'Identifier' },
\ { 'name': 'NamespaceName',                      'highlight': 'Identifier' },
\ { 'name': 'LabelName',                          'highlight': 'Label' },
\ { 'name': 'XmlDocCommentAttributeName',         'highlight': 0 },
\ { 'name': 'XmlDocCommentAttributeQuotes',       'highlight': 0 },
\ { 'name': 'XmlDocCommentAttributeValue',        'highlight': 0 },
\ { 'name': 'XmlDocCommentCDataSection',          'highlight': 0 },
\ { 'name': 'XmlDocCommentComment',               'highlight': 0 },
\ { 'name': 'XmlDocCommentDelimiter',             'highlight': 0 },
\ { 'name': 'XmlDocCommentEntityReference',       'highlight': 0 },
\ { 'name': 'XmlDocCommentName',                  'highlight': 0 },
\ { 'name': 'XmlDocCommentProcessingInstruction', 'highlight': 0 },
\ { 'name': 'XmlDocCommentText',                  'highlight': 0 },
\ { 'name': 'XmlLiteralAttributeName',            'highlight': 0 },
\ { 'name': 'XmlLiteralAttributeQuotes',          'highlight': 0 },
\ { 'name': 'XmlLiteralAttributeValue',           'highlight': 0 },
\ { 'name': 'XmlLiteralCDataSection',             'highlight': 0 },
\ { 'name': 'XmlLiteralComment',                  'highlight': 0 },
\ { 'name': 'XmlLiteralDelimiter',                'highlight': 0 },
\ { 'name': 'XmlLiteralEmbeddedExpression',       'highlight': 0 },
\ { 'name': 'XmlLiteralEntityReference',          'highlight': 0 },
\ { 'name': 'XmlLiteralName',                     'highlight': 0 },
\ { 'name': 'XmlLiteralProcessingInstruction',    'highlight': 0 },
\ { 'name': 'XmlLiteralText',                     'highlight': 0 },
\ { 'name': 'RegexComment',                       'highlight': 0 },
\ { 'name': 'RegexCharacterClass',                'highlight': 0 },
\ { 'name': 'RegexAnchor',                        'highlight': 0 },
\ { 'name': 'RegexQuantifier',                    'highlight': 0 },
\ { 'name': 'RegexGrouping',                      'highlight': 0 },
\ { 'name': 'RegexAlternation',                   'highlight': 0 },
\ { 'name': 'RegexText',                          'highlight': 0 },
\ { 'name': 'RegexSelfEscapedCharacter',          'highlight': 0 },
\ { 'name': 'RegexOtherEscape',                   'highlight': 0 }
\]

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
