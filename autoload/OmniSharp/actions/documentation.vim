let s:save_cpo = &cpoptions
set cpoptions&vim


function! OmniSharp#actions#documentation#TypeLookup(...) abort
  call s:TypeLookup(0, a:0 ? a:1 : 0)
endfunction

function! OmniSharp#actions#documentation#Documentation(...) abort
  call s:TypeLookup(1, a:0 ? a:1 : 0)
endfunction

" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the type (not the
" documentation)
function! s:TypeLookup(includeDocumentation, ...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  let opts.Doc = g:OmniSharp_typeLookupInPreview || a:includeDocumentation
  if g:OmniSharp_server_stdio
    call OmniSharp#stdio#TypeLookup(opts.Doc, function('s:CBTypeLookup', [opts]))
  else
    let pycmd = printf('typeLookup(%s)', opts.Doc ? 'True' : 'False')
    let response = OmniSharp#py#eval(pycmd)
    if OmniSharp#CheckPyError() | return | endif
    return s:CBTypeLookup(opts, response)
  endif
endfunction

function! s:CBTypeLookup(opts, response) abort
  let l:type = a:response.Type != v:null ? a:response.Type : ''
  if a:opts.Doc
    let content = trim(l:type . s:FormatDocumentation(a:response, 1))
    if OmniSharp#PreferPopups()
      let winid = OmniSharp#popup#Display(content, {})
      call setbufvar(winbufnr(winid), '&filetype', 'omnisharpdoc')
      call setwinvar(winid, '&conceallevel', 3)
    else
      let winid = s:PreviewDocumentation(content, 'Documentation')
    endif
  else
    echo l:type[0 : &columns * &cmdheight - 2]
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(l:type)
  endif
endfunction


function! OmniSharp#actions#documentation#SignatureHelp() abort
  if g:OmniSharp_server_stdio
    call OmniSharp#stdio#SignatureHelp(function('s:CBSignatureHelp'))
  else
    let response = OmniSharp#py#eval('signatureHelp()')
    if OmniSharp#CheckPyError() | return | endif
    call s:CBSignatureHelp(response)
  endif
endfunction

function! s:CBSignatureHelp(response) abort
  if type(a:response) != type({})
    echo 'No signature help found'
    if !OmniSharp#PreferPopups()
      " Clear existing preview content
      call s:PreviewDocumentation('', 'SignatureHelp')
    endif
    return
  endif

  let s:last = {
  \ 'Signatures': a:response.Signatures,
  \ 'SigIndex': a:response.ActiveSignature,
  \ 'ParamIndex': a:response.ActiveParameter
  \}
  call s:DisplaySignature(0, 0)
endfunction


function! s:DisplaySignature(deltaSig, deltaParam) abort
  let isig = s:last.SigIndex + a:deltaSig
  let isig =
  \ isig < 0 ? len(s:last.Signatures) - 1 :
  \ isig >= len(s:last.Signatures) ? 0 : isig
  let s:last.SigIndex = isig
  let signature = s:last.Signatures[isig]

  let content = signature.Label
  if len(s:last.Signatures) > 1
    let content .= printf("\n (overload %d of %d)",
    \ isig + 1, len(s:last.Signatures))
  endif

  let emphasis = {}
  if len(signature.Parameters)
    let iparam = s:last.ParamIndex + a:deltaParam
    let iparam =
    \ iparam < 0 ? 0 :
    \ iparam >= len(signature.Parameters) ? len(signature.Parameters) - 1 : iparam
    let s:last.ParamIndex = iparam
    let parameter = signature.Parameters[iparam]

    let content .= printf("\n\n`%s`: %s",
    \ parameter.Name, parameter.Documentation)
    let pos = matchstrpos(signature.Label, parameter.Label)
    if pos[1] >= 0 && pos[2] > pos[1]
      let emphasis = { 'start': pos[1] + 1, 'length': len(parameter.Label) }
    endif
  endif

  let content .= s:FormatDocumentation(signature, 0)

  if OmniSharp#PreferPopups()
    let winid = OmniSharp#popup#Display(content, {
    \ 'filter': function('s:PopupFilterSignature')
    \})
    call setbufvar(winbufnr(winid), '&filetype', 'omnisharpdoc')
    call setwinvar(winid, '&conceallevel', 3)
  else
    let winid = s:PreviewDocumentation(content, 'SignatureHelp')
  endif
  if has_key(emphasis, 'start') && has('textprop')
    call prop_type_add('OmniSharpActiveParameter', {
    \ 'bufnr': winbufnr(winid),
    \ 'highlight': 'OmniSharpActiveParameter'
    \})
    call prop_add(1, emphasis.start, {
    \ 'length': emphasis.length,
    \ 'bufnr': winbufnr(winid),
    \ 'type': 'OmniSharpActiveParameter'
    \})
  endif
endfunction

function! s:FormatDocumentation(doc, paramsAndExceptions) abort
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
    if a:paramsAndExceptions
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

function s:PopupFilterSignature(winid, key) abort
  " TODO: All of these filter keys should be be customisable
  if a:key ==# "\<C-n>"
    call s:DisplaySignature(1, 0)
  elseif a:key ==# "\<C-p>"
    call s:DisplaySignature(-1, 0)
  elseif a:key ==# "\<C-l>"
    call s:DisplaySignature(0, 1)
  elseif a:key ==# "\<C-h>"
    call s:DisplaySignature(0, -1)
  else
    return OmniSharp#popup#FilterStandard(a:winid, a:key)
  endif
  return v:true
endfunction


function! s:PreviewDocumentation(content, title)
  execute 'silent pedit' a:title
  silent wincmd P
  setlocal modifiable noreadonly
  setlocal nobuflisted buftype=nofile bufhidden=wipe
  0,$d
  silent put =a:content
  0d_
  setfiletype omnisharpdoc
  setlocal conceallevel=3
  setlocal nomodifiable readonly
  let winid = winnr()
  silent wincmd p
  return winid
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
