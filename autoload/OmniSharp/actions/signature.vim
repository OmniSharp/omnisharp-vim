let s:save_cpo = &cpoptions
set cpoptions&vim

let s:seq = get(s:, 'seq', 0)

function! OmniSharp#actions#signature#SignatureHelp(...) abort
  let opts = a:0 ? a:1 : {}
  if g:OmniSharp_server_stdio
    call s:StdioSignatureHelp(function('s:CBSignatureHelp', [opts]), opts)
  else
    let response = OmniSharp#py#eval('signatureHelp()')
    if OmniSharp#CheckPyError() | return | endif
    call s:CBSignatureHelp(response)
  endif
endfunction

function! s:StdioSignatureHelp(Callback, opts) abort
  let s:seq += 1
  let opts = {
  \ 'ResponseHandler': function('s:StdioSignatureHelpRH',
  \   [a:Callback, s:seq, a:opts])
  \}
  if has_key(a:opts, 'ForPopupMethod')
    " Awkward hack required:
    " We are requesting signatureHelp from a completion popup. This means our
    " line currently looks something like this:
    "   Console.Write|
    " However, OmniSharp-roslyn will only provide signatureHelp when the cursor
    " follows a full method name with opening parenthesis, like this:
    "   Console.Write(|
    " We therefore need to add a '(' to the request and move the cursor
    " position.
    let line = getline('.')
    let col = col('.')
    let opts.OverrideBuffer = {
    \ 'Line': line[0 : col - 2] . '(' . line[col - 1 :],
    \ 'LineNr': line('.'),
    \ 'Col': col + 1
    \}
  endif
  call OmniSharp#stdio#Request('/signaturehelp', opts)
endfunction

function! s:StdioSignatureHelpRH(Callback, seq, opts, response) abort
  if !a:response.Success | return | endif
  if s:seq != a:seq
    " Another SignatureHelp request has been made so ignore this response and
    " wait for the latest response to complete
    return
  endif
  if has_key(a:opts, 'ForPopupMethod')
    " Because of our 'falsified' request with an extra '(', re-synchronise the
    " server's version of the buffer with the actual buffer contents.
    call OmniSharp#UpdateBuffer()
  endif
  call a:Callback(a:response.Body)
endfunction

function! s:CBSignatureHelp(opts, response) abort
  if type(a:response) != type({})
    if !has_key(a:opts, 'ForPopupMethod')
      echo 'No signature help found'
    endif
    if !OmniSharp#PreferPopups()
      " Clear existing preview content
      call OmniSharp#preview#Display('', 'SignatureHelp')
    endif
    return
  endif
  let activeSignature = a:response.ActiveSignature
  if has_key(a:opts, 'ForPopupMethod')
    let idx = 0
    for signature in a:response.Signatures
      if stridx(signature.Label, a:opts.ForPopupMethod) >= 0
        let activeSignature = idx
        break
      endif
      let idx += 1
    endfor
  endif
  let s:last = {
  \ 'Signatures': a:response.Signatures,
  \ 'SigIndex': activeSignature,
  \ 'ParamIndex': a:response.ActiveParameter
  \}
  if has_key(a:opts, 'winid')
    let s:last.winid = a:opts.winid
  endif
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

  let content .= OmniSharp#actions#documentation#Format(signature, {
  \ 'paramsAndExceptions': 0
  \})

  if OmniSharp#PreferPopups()
    let opts = {
    \ 'filter': function('s:PopupFilterSignature')
    \}
    if has_key(s:last, 'winid')
      let opts.winid = s:last.winid
    endif
    let winid = OmniSharp#popup#Display(content, opts)
    call setbufvar(winbufnr(winid), '&filetype', 'omnisharpdoc')
    call setwinvar(winid, '&conceallevel', 3)
  else
    let winid = OmniSharp#preview#Display(content, 'SignatureHelp')
  endif
  if has_key(emphasis, 'start') && has('textprop')
    let propTypes = prop_type_list({'bufnr': winbufnr(winid)})
    if index(propTypes, 'OmniSharpActiveParameter') < 0
      call prop_type_add('OmniSharpActiveParameter', {
      \ 'bufnr': winbufnr(winid),
      \ 'highlight': 'OmniSharpActiveParameter'
      \})
    endif
    call prop_add(1, emphasis.start, {
    \ 'length': emphasis.length,
    \ 'bufnr': winbufnr(winid),
    \ 'type': 'OmniSharpActiveParameter'
    \})
  endif
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

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
