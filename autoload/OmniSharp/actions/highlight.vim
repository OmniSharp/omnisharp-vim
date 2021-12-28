let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#highlight#Buffer(...) abort
  let bufnr = a:0 ? a:1 : bufnr('%')
  if bufname(bufnr) ==# '' || OmniSharp#FugitiveCheck() | return | endif
  if getbufvar(bufnr, 'OmniSharp_debounce_highlight', 0)
    call timer_stop(getbufvar(bufnr, 'OmniSharp_debounce_highlight'))
  endif
  call setbufvar(bufnr, 'OmniSharp_debounce_highlight',
  \ timer_start(200, function('s:HighlightBuffer', [bufnr])))
endfunction

function! s:HighlightBuffer(bufnr, timer) abort
  if g:OmniSharp_server_stdio &&
  \ (has('textprop') || exists('*nvim_create_namespace'))
    call s:StdioHighlight(a:bufnr)
  else
    " Full semantic highlighting not supported - highlight types instead
    call OmniSharp#actions#highlight_types#Buffer()
  endif
endfunction

function! s:StdioHighlight(bufnr) abort
  let buftick = getbufvar(a:bufnr, 'changedtick')
  let opts = {
  \ 'ResponseHandler': function('s:HighlightRH', [a:bufnr, buftick]),
  \ 'BufNum': a:bufnr,
  \ 'SendBuffer': 0,
  \ 'ReplayOnLoad': 1
  \}
  call OmniSharp#stdio#Request('/v2/highlight', opts)
endfunction

function! s:HighlightRH(bufnr, buftick, response) abort
  if !a:response.Success | return | endif
  if getbufvar(a:bufnr, 'changedtick') != a:buftick
    " The buffer has changed while fetching highlights: fetch fresh highlights
    " from the server.
    " If in insert mode, only continue highlighting if the user
    " has configured _all_ highlighting triggers.
    if mode() ==# 'n' || get(g:, 'OmniSharp_highlighting', 0) >= 3
      call OmniSharp#actions#highlight#Buffer(a:bufnr)
    endif
    return
  endif
  let hasNvim = has('nvim')
  call s:InitialiseHighlights()
  if hasNvim
    let nsid = nvim_create_namespace('OmniSharpHighlight')
    call nvim_buf_clear_namespace(a:bufnr, nsid, 0, -1)
  endif
  let spans = get(a:response.Body, 'Spans', [])
  let curline = 1
  for span in spans
    if !hasNvim
      if curline <= span.EndLine
        try
          call prop_clear(curline, span.EndLine, {'bufnr': a:bufnr})
        catch | endtry
        let curline = span.EndLine + 1
      endif
    endif
    let shc = s:GetHighlight(span.Type, hasNvim)
    if type(shc.highlight) == v:t_string
      try
        let startCol = OmniSharp#util#CharToByteIdx(
        \ a:bufnr, span.StartLine, span.StartColumn)
        let endCol = OmniSharp#util#CharToByteIdx(
        \ a:bufnr, span.EndLine, span.EndColumn)
        if !hasNvim
          let endLine = span.EndLine
          if endCol == 1 && endLine > span.StartLine
            " When a span runs to the end of the line, OmniSharp-roslyn returns
            " this span as ending at character 1 of the following line. However,
            " Vim will then display this highlight on the first character of the
            " line, which is incorrect.
            let endLine = endLine - 1
            let endCol = 9999
          endif
          call prop_add(span.StartLine, startCol, {
          \ 'end_lnum': endLine,
          \ 'end_col': endCol,
          \ 'type': 'OSHighlight' . shc.name,
          \ 'bufnr': a:bufnr
          \})
        else
          for linenr in range(span.StartLine - 1, span.EndLine - 1)
            call nvim_buf_add_highlight(a:bufnr, nsid,
            \ shc.highlight,
            \ linenr,
            \ (linenr > span.StartLine - 1) ? 0 : startCol - 1,
            \ (linenr < span.EndLine - 1) ? -1 : endCol - 1)
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

function! s:GetHighlight(type, hasNvim) abort
  let shc = copy(s:ClassificationTypeNames[a:type])
  if has_key(get(g:, 'OmniSharp_highlight_groups', {}), shc.name)
    let shc.highlight = g:OmniSharp_highlight_groups[shc.name]
  endif
  if !a:hasNvim && type(shc.highlight) == v:t_string
    let propName = 'OSHighlight' . shc.name
    let prop = prop_type_get(propName)
    if !has_key(prop, 'highlight')
      call prop_type_add(propName, {'highlight': shc.highlight, 'combine': 1})
    elseif prop.highlight !=# shc.highlight
      call prop_type_change(propName, {'highlight': shc.highlight})
    endif
  endif
  return shc
endfunction

function! s:InitialiseHighlights() abort
  if get(s:, 'highlightsInitialized') | return | endif
  let s:highlightsInitialized = 1
  " For backwards-compatibility, check for the old g:OmniSharp_highlight_groups
  " structure, and convert it to the new style.
  let hlgroups = copy(get(g:, 'OmniSharp_highlight_groups', {}))
  if len(hlgroups) > 0 && type(values(hlgroups)[0]) == v:t_list
    let g:OmniSharp_highlight_groups = {}
    for [highlight, groups] in items(hlgroups)
      for group in groups
        let shc = filter(copy(s:ClassificationTypeNames), 'v:val.desc == group')
        if len(shc) > 0
          let g:OmniSharp_highlight_groups[shc[0].name] = highlight
        endif
      endfor
    endfor
    " Since the old g:OmniAhrp_highlight_groups are being used, the old
    " csUser... highlight groups may also be expected, so initialise them
    call OmniSharp#actions#highlight_types#Initialise()
  endif
endfunction

function OmniSharp#actions#highlight#Echo() abort
  if !g:OmniSharp_server_stdio
    echo 'Highlight kinds can only be used in stdio mode'
    return
  endif
  let hasNvim = has('nvim')
  if !hasNvim && !has('textprop')
    echo 'Highlight kinds requires text properties - your Vim is too old'
    return
  elseif hasNvim && !exists('*nvim_create_namespace')
    echo 'Highlight kinds requires namespaces - your neovim is too old'
    return
  endif
  let currentSpans = 0
  for span in get(s:, 'lastSpans', [])
    let startCol = OmniSharp#util#CharToByteIdx(
    \ bufnr('%'), span.StartLine, span.StartColumn)
    let endCol = OmniSharp#util#CharToByteIdx(
    \ bufnr('%'), span.EndLine, span.EndColumn)
    if span.StartLine <= line('.') && span.EndLine >= line('.')
      let line = line('.')
      let col = col('.')
      if (span.StartLine == span.EndLine && startCol <= col && endCol > col)
      \ || (span.StartLine < line && span.EndLine > line)
      \ || (span.StartLine < line && endCol > col)
      \ || (span.EndLine > line && startCol <= col)
        let currentSpans += 1
        let shc = s:GetHighlight(span.Type, hasNvim)
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

" All classifications from Roslyn's ClassificationTypeNames
" https://github.com/dotnet/roslyn/blob/master/src/Workspaces/Core/Portable/Classification/ClassificationTypeNames.cs
" Keep in sync with omnisharp-roslyn's ClassificationTypeNames
"
" Structured as an array of dicts instead of an ordinary dict so records can be
" accessed by index. Endpoint /v2/highlight provides `Type` as an integer index.
let s:ClassificationTypeNames = [
\ { 'name': 'Comment',                            'highlight': 0 ,            'desc': 'comment'},
\ { 'name': 'ExcludedCode',                       'highlight': 'NonText' ,    'desc': 'excluded code'},
\ { 'name': 'Identifier',                         'highlight': 'Identifier' , 'desc': 'identifier'},
\ { 'name': 'Keyword',                            'highlight': 0 ,            'desc': 'keyword'},
\ { 'name': 'ControlKeyword',                     'highlight': 0 ,            'desc': 'keyword - control'},
\ { 'name': 'NumericLiteral',                     'highlight': 0 ,            'desc': 'number'},
\ { 'name': 'Operator',                           'highlight': 0 ,            'desc': 'operator'},
\ { 'name': 'OperatorOverloaded',                 'highlight': 0 ,            'desc': 'operator - overloaded'},
\ { 'name': 'PreprocessorKeyword',                'highlight': 0 ,            'desc': 'preprocessor keyword'},
\ { 'name': 'StringLiteral',                      'highlight': 0 ,            'desc': 'string'},
\ { 'name': 'WhiteSpace',                         'highlight': 0 ,            'desc': 'whitespace'},
\ { 'name': 'Text',                               'highlight': 0 ,            'desc': 'text'},
\ { 'name': 'StaticSymbol',                       'highlight': 'Identifier' , 'desc': 'static symbol'},
\ { 'name': 'PreprocessorText',                   'highlight': 0 ,            'desc': 'preprocessor text'},
\ { 'name': 'Punctuation',                        'highlight': 0 ,            'desc': 'punctuation'},
\ { 'name': 'VerbatimStringLiteral',              'highlight': 0 ,            'desc': 'string - verbatim'},
\ { 'name': 'StringEscapeCharacter',              'highlight': 0 ,            'desc': 'string - escape character'},
\ { 'name': 'ClassName',                          'highlight': 'Typedef' ,    'desc': 'class name'},
\ { 'name': 'DelegateName',                       'highlight': 'Structure' ,  'desc': 'delegate name'},
\ { 'name': 'EnumName',                           'highlight': 'Structure' ,  'desc': 'enum name'},
\ { 'name': 'InterfaceName',                      'highlight': 'Structure' ,  'desc': 'interface name'},
\ { 'name': 'ModuleName',                         'highlight': 'Structure' ,  'desc': 'module name'},
\ { 'name': 'StructName',                         'highlight': 'Typedef' ,    'desc': 'struct name'},
\ { 'name': 'TypeParameterName',                  'highlight': 'Type' ,       'desc': 'type parameter name'},
\ { 'name': 'FieldName',                          'highlight': 'Identifier' , 'desc': 'field name'},
\ { 'name': 'EnumMemberName',                     'highlight': 'Identifier' , 'desc': 'enum member name'},
\ { 'name': 'ConstantName',                       'highlight': 'Identifier' , 'desc': 'constant name'},
\ { 'name': 'LocalName',                          'highlight': 'Identifier' , 'desc': 'local name'},
\ { 'name': 'ParameterName',                      'highlight': 'Identifier' , 'desc': 'parameter name'},
\ { 'name': 'MethodName',                         'highlight': 'Function' ,   'desc': 'method name'},
\ { 'name': 'ExtensionMethodName',                'highlight': 'Function' ,   'desc': 'extension method name'},
\ { 'name': 'PropertyName',                       'highlight': 'Identifier' , 'desc': 'property name'},
\ { 'name': 'EventName',                          'highlight': 'Identifier' , 'desc': 'event name'},
\ { 'name': 'NamespaceName',                      'highlight': 'Include' ,    'desc': 'namespace name'},
\ { 'name': 'LabelName',                          'highlight': 'Label' ,      'desc': 'label name'},
\ { 'name': 'XmlDocCommentAttributeName',         'highlight': 0 ,            'desc': 'xml doc comment - attribute name'},
\ { 'name': 'XmlDocCommentAttributeQuotes',       'highlight': 0 ,            'desc': 'xml doc comment - attribute quotes'},
\ { 'name': 'XmlDocCommentAttributeValue',        'highlight': 0 ,            'desc': 'xml doc comment - attribute value'},
\ { 'name': 'XmlDocCommentCDataSection',          'highlight': 0 ,            'desc': 'xml doc comment - cdata section'},
\ { 'name': 'XmlDocCommentComment',               'highlight': 0 ,            'desc': 'xml doc comment - comment'},
\ { 'name': 'XmlDocCommentDelimiter',             'highlight': 0 ,            'desc': 'xml doc comment - delimiter'},
\ { 'name': 'XmlDocCommentEntityReference',       'highlight': 0 ,            'desc': 'xml doc comment - entity reference'},
\ { 'name': 'XmlDocCommentName',                  'highlight': 0 ,            'desc': 'xml doc comment - name'},
\ { 'name': 'XmlDocCommentProcessingInstruction', 'highlight': 0 ,            'desc': 'xml doc comment - processing instruction'},
\ { 'name': 'XmlDocCommentText',                  'highlight': 0 ,            'desc': 'xml doc comment - text'},
\ { 'name': 'XmlLiteralAttributeName',            'highlight': 0 ,            'desc': 'xml literal - attribute name'},
\ { 'name': 'XmlLiteralAttributeQuotes',          'highlight': 0 ,            'desc': 'xml literal - attribute quotes'},
\ { 'name': 'XmlLiteralAttributeValue',           'highlight': 0 ,            'desc': 'xml literal - attribute value'},
\ { 'name': 'XmlLiteralCDataSection',             'highlight': 0 ,            'desc': 'xml literal - cdata section'},
\ { 'name': 'XmlLiteralComment',                  'highlight': 0 ,            'desc': 'xml literal - comment'},
\ { 'name': 'XmlLiteralDelimiter',                'highlight': 0 ,            'desc': 'xml literal - delimiter'},
\ { 'name': 'XmlLiteralEmbeddedExpression',       'highlight': 0 ,            'desc': 'xml literal - embedded expression'},
\ { 'name': 'XmlLiteralEntityReference',          'highlight': 0 ,            'desc': 'xml literal - entity reference'},
\ { 'name': 'XmlLiteralName',                     'highlight': 0 ,            'desc': 'xml literal - name'},
\ { 'name': 'XmlLiteralProcessingInstruction',    'highlight': 0 ,            'desc': 'xml literal - processing instruction'},
\ { 'name': 'XmlLiteralText',                     'highlight': 0 ,            'desc': 'xml literal - text'},
\ { 'name': 'RegexComment',                       'highlight': 'Comment' ,    'desc': 'regex - comment'},
\ { 'name': 'RegexCharacterClass',                'highlight': 'Character' ,  'desc': 'regex - character class'},
\ { 'name': 'RegexAnchor',                        'highlight': 'Type' ,       'desc': 'regex - anchor'},
\ { 'name': 'RegexQuantifier',                    'highlight': 'Number' ,     'desc': 'regex - quantifier'},
\ { 'name': 'RegexGrouping',                      'highlight': 'Macro' ,      'desc': 'regex - grouping'},
\ { 'name': 'RegexAlternation',                   'highlight': 'Identifier' , 'desc': 'regex - alternation'},
\ { 'name': 'RegexText',                          'highlight': 'String' ,     'desc': 'regex - text'},
\ { 'name': 'RegexSelfEscapedCharacter',          'highlight': 'Delimiter' ,  'desc': 'regex - self escaped character'},
\ { 'name': 'RegexOtherEscape',                   'highlight': 'Delimiter' ,  'desc': 'regex - other escape'}
\]

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
