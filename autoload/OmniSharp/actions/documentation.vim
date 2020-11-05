let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#documentation#TypeLookup(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  let opts.Doc = g:OmniSharp_typeLookupInPreview
  if g:OmniSharp_server_stdio
    call s:StdioTypeLookup(opts.Doc, function('s:CBTypeLookup', [opts]), opts)
  else
    let pycmd = printf('typeLookup(%s)', opts.Doc ? 'True' : 'False')
    let response = OmniSharp#py#Eval(pycmd)
    if OmniSharp#py#CheckForError() | return | endif
    return s:CBTypeLookup(opts, response)
  endif
endfunction

function! OmniSharp#actions#documentation#Documentation(...) abort
  let opts = a:0 ? a:1 : {}
  let opts.Doc = 1
  if g:OmniSharp_server_stdio
    call s:StdioTypeLookup(opts.Doc, function('s:CBTypeLookup', [opts]), opts)
  else
    let pycmd = printf('typeLookup(%s)', opts.Doc ? 'True' : 'False')
    let response = OmniSharp#py#Eval(pycmd)
    if OmniSharp#py#CheckForError() | return | endif
    return s:CBTypeLookup(opts, response)
  endif
endfunction

function! s:StdioTypeLookup(includeDocumentation, Callback, opts) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioTypeLookupRH', [a:Callback]),
  \ 'Parameters': {
  \    'IncludeDocumentation': a:includeDocumentation ? 'true' : 'false'
  \ }
  \}
  if has_key(a:opts, 'ForCompletion')
    " Awkward hacks required.
    " When arrow-keys are used instead of CTRL-N/CTRL-P for navigating through
    " completion options, we will have lines like this:
    "   Console.|
    " or
    "   Console.Bee|
    " For fetching documentation, we need the full property name, like this:
    "   Console.Beep|
    let line = getline('.')
    let col = col('.')
    let property = a:opts.ForCompletion
    let propertylen = len(property)
    let tmpline = line[0 : col - 2]
    let add = ''
    let added = 0
    while added < propertylen && tmpline !~# property . '$'
      let add = property[len(property) - 1 :] . add
      let property = property[: len(property) - 2]
      let added += 1
    endwhile
    let tmpline .= add . line[col - 1 :]
    let opts.OverrideBuffer = {
    \ 'Line': tmpline,
    \ 'LineNr': line('.'),
    \ 'Col': col
    \}
  endif
  call OmniSharp#stdio#Request('/typelookup', opts)
endfunction

function! s:StdioTypeLookupRH(Callback, response) abort
  if !a:response.Success
    call a:Callback({ 'Type': '', 'Documentation': '' })
    return
  endif
  call a:Callback(a:response.Body)
endfunction

function! s:CBTypeLookup(opts, response) abort
  let l:type = a:response.Type != v:null ? a:response.Type : ''
  if a:opts.Doc
    let content = OmniSharp#util#Trim(
    \ l:type . OmniSharp#actions#documentation#Format(a:response, {}))
    if OmniSharp#popup#Enabled()
      if has_key(a:opts, 'ForCompletion')
        " If the popupmenu has already closed, exit early
        if !pumvisible() | return | endif
      endif
      let winid = OmniSharp#popup#Display(content, a:opts)
      call setbufvar(winbufnr(winid), '&filetype', 'omnisharpdoc')
      call setwinvar(winid, '&conceallevel', 3)
    else
      let winid = OmniSharp#preview#Display(content, 'Documentation')
    endif
  else
    echo l:type[0 : &columns * &cmdheight - 2]
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(l:type)
  endif
endfunction

function! OmniSharp#actions#documentation#Format(doc, opts) abort
  let content = ''
  if has_key(a:doc, 'StructuredDocumentation')
  \ && type(a:doc.StructuredDocumentation) == type({})
    let doc = a:doc.StructuredDocumentation
    for text in ['Summary', 'Returns', 'Remarks', 'Example', 'Value']
      if get(doc, text . 'Text', '') !=# ''
        if text ==# 'Summary'
          let content .= "\n\n" . doc[text . 'Text']
        else
          let content .= "\n\n## " . text . "\n" . doc[text . 'Text']
        endif
      endif
    endfor
    if get(a:opts, 'ParamsAndExceptions', 1)
      if len(doc.ParamElements)
        let content .= "\n\n## Parameters"
      endif
      for param in doc.ParamElements
        let content .= "\n`" . param.Name . "`\n" . param.Documentation
      endfor
      if len(doc.Exception)
        let content .= "\n\n## Exceptions"
      endif
      for exc in doc.Exception
        let content .= "\n`" . exc.Name . "`\n" . exc.Documentation
      endfor
    endif
  elseif a:doc.Documentation != v:null
    let content .= "\n\n" . a:doc.Documentation
  endif
  return content
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
