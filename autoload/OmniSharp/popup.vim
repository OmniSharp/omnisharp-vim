let s:save_cpo = &cpoptions
set cpoptions&vim

let g:OmniSharp.popup = get(g:OmniSharp, 'popup', {})

function! OmniSharp#popup#Buffer(bufnr, lnum, opts) abort
  let a:opts.firstline = a:lnum
  return s:Open(a:bufnr, a:opts)
endfunction

function! OmniSharp#popup#Display(content, opts) abort
  let content = map(split(a:content, "\n", 1),
  \ {i,v -> substitute(v, '\r', '', 'g')})
  if has_key(a:opts, 'winid')
    " a:opts.winid is currently only set when using SignatureHelp for completion
    " method documentation. This is Vim only, until neovim implements
    " completeopt+=popup (or we write our own version).
    let popupOpts = s:VimGetOptions(a:opts)
    call popup_setoptions(a:opts.winid, popupOpts)
    call popup_settext(a:opts.winid, split(a:content, "\n"))
    if !popup_getpos(a:opts.winid).visible
      call popup_show(a:opts.winid)
    endif
    return a:opts.winid
  else
    return s:Open(content, a:opts)
  endif
endfunction

function! OmniSharp#popup#Enabled() abort
  if type(g:OmniSharp.popup) == type(0) && g:OmniSharp.popup == 0
    return 0
  endif
  if !exists('s:supports_popups')
    let s:supports_popups = 1
    if has('nvim')
      if !exists('*nvim_open_win')
        call OmniSharp#util#EchoErr(
        \ 'A newer version of neovim is required to support floating windows')
        let s:supports_popups = 0
      endif
    else
      if !has('patch-8.1.1963')
        call OmniSharp#util#EchoErr(
        \ 'A newer version of Vim is required to support popup windows')
        let s:supports_popups = 0
      endif
    endif
  endif
  if !s:supports_popups
    return 0
  endif
  if type(g:OmniSharp.popup) != type({})
    let g:OmniSharp.popup = {}
  endif
  return 1
endfunction

" Create temporary, buffer-local mappings if buffer-local lhs(s) do not
" already exist. The mappings will be removed as soon as the popup window is
" closed.
function! OmniSharp#popup#Map(mode, mapName, defaultLHS, funcall) abort
  let maps = get(g:OmniSharp.popup, 'mappings', {})
  let configLHS = get(maps, a:mapName, a:defaultLHS)
  if configLHS is 0 | return | endif
  for lhs in type(configLHS) == type([]) ? configLHS : [configLHS]
    if get(maparg(lhs, a:mode, 0, 1), 'buffer', 0)
      let s:popupMapWarnings = get(s:, 'popupMapWarnings', [])
      if index(s:popupMapWarnings, lhs) == -1
        echohl WarningMsg
        echomsg printf('Mapping exists: %s. Skipping', lhs)
        echohl None
        call add(s:popupMapWarnings, lhs)
      endif
    else
      execute printf(
      \ '%snoremap <buffer> <nowait> <expr> %s <SID>PopupMapWrapper("%s")',
      \ a:mode, lhs, a:funcall)
      call add(s:popupMaps, [a:mode, lhs])
    endif
  endfor
endfunction


function s:CloseLast(redraw) abort
  if exists('s:lastwinid')
    if has('nvim')
      call nvim_win_close(s:lastwinid, v:true)
      if exists('#OmniSharp_nvim_popup')
        autocmd! OmniSharp_nvim_popup
      endif
    else
      call popup_close(s:lastwinid)
      if a:redraw
        redraw
      endif
    endif
    call s:Unmap()
    unlet s:lastwinid
  endif
endfunction

" Mimic Vim behaviour in neovim: close the window when the cursor is moved to a
" different line
function s:CloseLastNvimOnMove() abort
  if line('.') != s:lastwinpos[0]
    call s:CloseLast(0)
  endif
endfunction

function s:Open(what, opts) abort
  call s:CloseLast(0)
  let s:popupMaps = []
  let s:lastwinpos = [line('.'), col('.')]
  let mode = get(a:opts, 'mode', mode())
  if has('nvim')
    let s:lastwinid = s:NvimOpen(a:what, a:opts)
    call OmniSharp#popup#Map(mode, 'lineDown',     '<C-e>', "<SID>NvimPopupNormal('e')")
    call OmniSharp#popup#Map(mode, 'lineUp',       '<C-y>', "<SID>NvimPopupNormal('y')")
    call OmniSharp#popup#Map(mode, 'halfPageDown', '<C-d>', "<SID>NvimPopupNormal('d')")
    call OmniSharp#popup#Map(mode, 'halfPageUp',   '<C-u>', "<SID>NvimPopupNormal('u')")
    call OmniSharp#popup#Map(mode, 'pageDown',     '<C-f>', "<SID>NvimPopupNormal('f')")
    call OmniSharp#popup#Map(mode, 'pageUp',       '<C-b>', "<SID>NvimPopupNormal('b')")
  else
    let s:lastwinid = s:VimOpen(a:what, a:opts)
    call OmniSharp#popup#Map(mode, 'lineDown',     '<C-e>', '<SID>VimPopupScrollLine(1)')
    call OmniSharp#popup#Map(mode, 'lineUp',       '<C-y>', '<SID>VimPopupScrollLine(-1)')
    call OmniSharp#popup#Map(mode, 'halfPageDown', '<C-d>', '<SID>VimPopupScrollPage(0.5)')
    call OmniSharp#popup#Map(mode, 'halfPageUp',   '<C-u>', '<SID>VimPopupScrollPage(-0.5)')
    call OmniSharp#popup#Map(mode, 'pageDown',     '<C-f>', '<SID>VimPopupScrollPage(1)')
    call OmniSharp#popup#Map(mode, 'pageUp',       '<C-b>', '<SID>VimPopupScrollPage(-1)')
  endif
  call OmniSharp#popup#Map(mode, 'close', '<Esc>', '<SID>CloseLast(1)')
  if mode !=# 'n'
    call OmniSharp#popup#Map('n', 'close', '<Esc>', '<SID>CloseLast(1)')
  endif
  return s:lastwinid
endfunction

function s:NvimGetOptions() abort
  if !exists('s:initialised')
    let defaultOptions = {
    \ 'wrap': v:true
    \}
    let g:OmniSharp.popup.options = get(g:OmniSharp.popup, 'options', {})
    call extend(g:OmniSharp.popup.options, defaultOptions, 'keep')
    let s:initialised = 1
  endif
  return g:OmniSharp.popup.options
endfunction

function! s:NvimOpen(what, opts) abort
  if type(a:what) == v:t_number
    let bufnr = a:what
    let lines = getbufline(bufnr, 1, '$')
  else
    let bufnr = nvim_create_buf(v:false, v:true)
    call setbufline(bufnr, 1, a:what)
    let lines = a:what
  endif
  " TODO: Open 'peekable' popups (buffers, not documentation) in different
  " positions: atcursor, as a 'peek', 'centered'
  let content_height = len(lines)
  " Initial height: full screen height, so window height (including wrapped
  " lines) can be calculated below
  let height = &lines
  let content_width = max(map(lines, 'len(v:val)'))
  let available = &columns - screencol()
  let width = max([50, min([available, content_width])])
  let config = {
  \ 'relative': 'cursor',
  \ 'width': width,
  \ 'height': height,
  \ 'row': 1,
  \ 'col': 1,
  \ 'focusable': v:false,
  \ 'style': 'minimal'
  \}
  let s:parentwinid = win_getid(winnr())
  let winid = nvim_open_win(bufnr, v:false, config)
  let options = s:NvimGetOptions()
  for opt in keys(options)
    call nvim_win_set_option(winid, opt, options[opt])
  endfor
  call nvim_set_current_win(winid)
  " Go to bottom of popup and use winline() to find the actual window height
  normal! G$
  let height = max([winline(), content_height])
  call nvim_win_set_config(winid, { 'height': height })
  if has_key(a:opts, 'firstline')
    execute 'normal!' a:opts.firstline . 'Gzt'
  else
    normal! G0
  endif
  call nvim_set_current_win(s:parentwinid)
  augroup OmniSharp_nvim_popup
    autocmd CursorMoved <buffer> call s:CloseLastNvimOnMove()
    autocmd CursorMovedI <buffer> call s:CloseLastNvimOnMove()
  augroup END
  return winid
endfunction

" Neovim scrolling works by giving focus to the popup and running normal-mode
" commands
function! s:NvimPopupNormal(commands)
  call nvim_set_current_win(s:lastwinid)
  execute 'normal!' eval(printf('"\<C-%s>"', a:commands))
  call nvim_set_current_win(s:parentwinid)
endfunction

" Editing buffers is not allowed from <expr> mappings. The popup mappings are
" all <expr> mappings so they can be used consistently across modes, so instead
" of running the functions directly, they are run in an immediately executed
" timer callback.
function! s:PopupMapWrapper(funcall) abort
  execute printf('call timer_start(0, {-> %s})', a:funcall)
  return "\<Ignore>"
endfunction

function s:VimGetOptions(opts) abort
  if !exists('s:initialised')
    let defaultOptions = {
    \ 'mapping': v:true,
    \ 'scrollbar': v:true
    \}
    let g:OmniSharp.popup.options = get(g:OmniSharp.popup, 'options', {})
    call extend(g:OmniSharp.popup.options, defaultOptions, 'keep')
    let s:initialised = 1
  endif
  return extend(copy(g:OmniSharp.popup.options), a:opts)
endfunction

function! s:VimOpen(what, opts) abort
  let popupOpts = s:VimGetOptions(a:opts)
  let popupOpts.callback = function('s:Unmap')
  " TODO: Open 'peekable' popups (buffers, not documentation) in different
  " positions: atcursor, as a 'peek', 'centered'
  let winid = popup_atcursor(a:what, popupOpts)
  return winid
endfunction

" Popup scrolling functions by @bfrg from https://github.com/vim/vim/issues/5170
function! s:VimPopupScrollLine(step) abort
  let line = popup_getoptions(s:lastwinid).firstline
  if a:step < 0
    let newline = (line + a:step) > 0 ? (line + a:step) : 1
  else
    let nlines = line('$', s:lastwinid)
    let newline = (line + a:step) <= nlines ? (line + a:step) : nlines
  endif
  call popup_setoptions(s:lastwinid, {'firstline': newline})
endfunction

function! s:VimPopupScrollPage(size) abort
  let height = popup_getpos(s:lastwinid).core_height
  let step = float2nr(height * a:size)
  call s:VimPopupScrollLine(step)
endfunction

function s:Unmap(...) abort
  for popupmap in get(s:, 'popupMaps', [])
    try
      execute popupmap[0] . 'unmap <buffer>' popupmap[1]
    catch | endtry
  endfor
  let s:popupMaps = []
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
