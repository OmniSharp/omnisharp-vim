let s:save_cpo = &cpoptions
set cpoptions&vim

let s:seq = get(s:, 'seq', 0)

function! OmniSharp#actions#signature#SignatureHelp(...) abort
  let opts = a:0 ? a:1 : {}
  if !has_key(opts, 'ForCompleteMethod')
    augroup OmniSharp_signature_help_insert
      autocmd!
      " Update the signature help box when new text is inserted.
      autocmd TextChangedI <buffer>
      \ call  OmniSharp#actions#signature#SignatureHelp()

      " Remove this augroup when leaving insert mode
      autocmd InsertLeave <buffer>
      \ autocmd! OmniSharp_signature_help_insert
    augroup END
  endif
  if g:OmniSharp_server_stdio
    call s:StdioSignatureHelp(function('s:CBSignatureHelp', [opts]), opts)
  else
    let response = OmniSharp#py#Eval('signatureHelp()')
    if OmniSharp#py#CheckForError() | return | endif
    call s:CBSignatureHelp(opts, response)
  endif
endfunction

function! s:StdioSignatureHelp(Callback, opts) abort
  let s:seq += 1
  let opts = {
  \ 'ResponseHandler': function('s:StdioSignatureHelpRH',
  \   [a:Callback, s:seq, a:opts])
  \}
  if has_key(a:opts, 'ForCompleteMethod')
    " Awkward hacks required:
    if !g:OmniSharp_want_snippet
      " We are requesting signatureHelp from a completion popup. This means our
      " line currently looks something like this:
      "   Console.Write|
      " However, OmniSharp-roslyn will only provide signatureHelp when the cursor
      " follows a full method name with opening parenthesis, like this:
      "   Console.Write(|
      " We therefore need to add a '(' to the request and move the cursor
      " position.
      "
      " When arrow-keys are used instead of CTRL-N, the method name is _not_
      " inserted, so instead of:
      "   Console.Write|
      " we just have:
      "   Console.|
      " or
      "   Console.Wri|
      " In this case, we need to add/complete the method name as well as the '('
      " in our request buffer.
      let line = getline('.')
      let col = col('.')
      let method = substitute(a:opts.ForCompleteMethod, '(.*$', '', '')
      let methodlen = len(method)
      let tmpline = line[0 : col - 2]
      let add = ''
      let added = 0
      while added < methodlen && tmpline !~# method . '$'
        let add = method[len(method) - 1 :] . add
        let method = method[: len(method) - 2]
        let added += 1
      endwhile
      let tmpline .= add . '(' . line[col - 1 :]
      let opts.OverrideBuffer = {
      \ 'Line': tmpline,
      \ 'LineNr': line('.'),
      \ 'Col': col + added + 1
      \}
    else
      " When g:OmniSharp_want_snippet == 1, the line returned from
      " OmniSharp-roslyn is different, and currently looks like this:
      "   Console.Write(.....)|
      " We don't need to modify this line, but we _do_ need to place the cursor
      " inside the parentheses.
      let opts.OverrideBuffer = {
      \ 'Line': getline('.'),
      \ 'LineNr': line('.'),
      \ 'Col': col('.') - 1
      \}
    endif
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
  if has_key(a:opts, 'ForCompleteMethod') && !g:OmniSharp_want_snippet
    " Because of our 'falsified' request with an extra '(', re-synchronise the
    " server's version of the buffer with the actual buffer contents.
    call OmniSharp#actions#buffer#Update({'SendBuffer': 1})
  endif
  call a:Callback(a:response.Body)
endfunction

function! s:CBSignatureHelp(opts, response) abort
  if type(a:response) != type({})
    if !has_key(a:opts, 'ForCompleteMethod')
      echo 'No signature help found'
    endif
    if !OmniSharp#popup#Enabled()
      " Clear existing preview content
      call OmniSharp#preview#Display('', 'SignatureHelp')
    endif
    return
  endif
  let s:last = {
  \ 'Signatures': a:response.Signatures,
  \ 'SigIndex': a:response.ActiveSignature,
  \ 'ParamIndex': a:response.ActiveParameter,
  \ 'EmphasizeActiveParam': 1,
  \ 'ParamsAndExceptions': 0,
  \ 'mode': mode()
  \}
  if has_key(a:opts, 'ForCompleteMethod')
    " If the popupmenu has already closed, exit early
    if !pumvisible() | return | endif
    let s:last.PopupMaps = 0
    let s:last.EmphasizeActiveParam = 0
    let s:last.ParamsAndExceptions = 1
    let idx = 0
    for signature in a:response.Signatures
      if stridx(signature.Label, a:opts.ForCompleteMethod) >= 0
        let s:last.SigIndex = idx
        break
      endif
      let idx += 1
    endfor
  endif
  if has_key(a:opts, 'winid')
    let s:last.winid = a:opts.winid
  endif
  call OmniSharp#actions#signature#Display(0, 0)
endfunction

function! OmniSharp#actions#signature#Display(deltaSig, deltaParam) abort
  let isig = s:last.SigIndex + a:deltaSig
  let isig =
  \ isig < 0 ? len(s:last.Signatures) - 1 :
  \ isig >= len(s:last.Signatures) ? 0 : isig
  if isig == -1
    return
  endif
  let s:last.SigIndex = isig
  let signature = s:last.Signatures[isig]

  let content = signature.Label
  if s:last.EmphasizeActiveParam && len(s:last.Signatures) > 1
    let content .= printf("\n (overload %d of %d)",
    \ isig + 1, len(s:last.Signatures))
  endif

  let emphasis = {}
  if s:last.EmphasizeActiveParam && len(signature.Parameters)
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
  \ 'ParamsAndExceptions': s:last.ParamsAndExceptions
  \})

  if OmniSharp#popup#Enabled()
    let opts = {}
    if has_key(s:last, 'winid')
      let opts.winid = s:last.winid
    endif
    if has_key(s:last, 'mode')
      let opts.mode = s:last.mode
    endif
    let winid = OmniSharp#popup#Display(content, opts)
    call setbufvar(winbufnr(winid), '&filetype', 'omnisharpdoc')
    call setwinvar(winid, '&conceallevel', 3)
    if get(s:last, 'PopupMaps', 1)
      call OmniSharp#popup#Map(s:last.mode, 'sigNext',      '<C-j>',
      \ 'OmniSharp#actions#signature#Display(1, 0)')
      call OmniSharp#popup#Map(s:last.mode, 'sigPrev',      '<C-k>',
      \ 'OmniSharp#actions#signature#Display(-1, 0)')
      call OmniSharp#popup#Map(s:last.mode, 'sigParamNext', '<C-l>',
      \ 'OmniSharp#actions#signature#Display(0, 1)')
      call OmniSharp#popup#Map(s:last.mode, 'sigParamPrev', '<C-h>',
      \ 'OmniSharp#actions#signature#Display(0, -1)')
    endif
  else
    let winid = OmniSharp#preview#Display(content, 'SignatureHelp')
  endif
  if has_key(emphasis, 'start')
    if !has('nvim') && has('textprop')
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
    elseif has('nvim') && exists('*nvim_create_namespace')
      let nsid = nvim_create_namespace('OmniSharp_signature_emphasis')
      call nvim_buf_add_highlight(winbufnr(winid), nsid,
      \ 'OmniSharpActiveParameter',
      \ 0, emphasis.start - 1, emphasis.start + emphasis.length - 1)
    endif
  endif
  redraw
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
