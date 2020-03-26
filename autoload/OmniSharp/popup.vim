let s:save_cpo = &cpoptions
set cpoptions&vim

let g:OmniSharp_popup_opts = get(g:, 'OmniSharp_popup_opts', {
\ 'highlight': 'PMenu',
\ 'padding': [0,1,1,1],
\ 'border': [1,0,0,0],
\ 'borderchars': [' '],
\ 'mapping': v:true,
\ 'scrollbar': v:true
\})

function! OmniSharp#popup#Buffer(bufnr, lnum, opts) abort
  let a:opts.firstline = a:lnum
  return s:Open(a:bufnr, a:opts)
endfunction

function! OmniSharp#popup#Display(content, opts) abort
  let content = map(split(a:content, "\n", 1),
  \ {i,v -> substitute(v, '\r', '', 'g')})
  if has_key(a:opts, 'winid')
    let popupOpts = s:GetVimOptions(a:opts)
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

function s:GetNvimOptions(opts) abort
  return {
  \ 'relative': 'cursor',
  \ 'width': max([&columns / 2, 80]),
  \ 'height': max([&lines / 2, 10]),
  \ 'row': 1,
  \ 'col': 1,
  \ 'focusable': v:false,
  \ 'style': 'minimal'
  \}
endfunction

function s:GetVimOptions(opts) abort
  let popupOpts = copy(g:OmniSharp_popup_opts)
  if len(keys(a:opts))
    call extend(popupOpts, a:opts)
  endif
  return popupOpts
endfunction

function s:Open(what, opts) abort
  call s:CloseLast(0)
  let s:popupMaps = []
  let s:lastwinpos = [line('.'), col('.')]
  let mode = get(a:opts, 'mode', mode())
  if has('nvim')
    if type(a:what) == v:t_number
      let bufnr = a:what
    else
      let bufnr = nvim_create_buf(v:false, v:true)
      call setbufline(bufnr, 1, a:what)
      " call nvim_buf_set_lines(bufnr, 1, 1, 0, a:what)
    endif
    let s:lastwinid = nvim_open_win(bufnr, v:false, s:GetNvimOptions(a:opts))
    let s:parentwinid = win_getid(winnr())
    if has_key(a:opts, 'firstline')
      call s:NvimPopupNormal(a:opts.firstline . 'Gzt', 0)
    endif
    call nvim_win_set_option(s:lastwinid, 'wrap', v:true)
    augroup OmniSharp_nvim_popup
      autocmd CursorMoved <buffer> call s:CloseLastNvimOnMove()
      autocmd CursorMovedI <buffer> call s:CloseLastNvimOnMove()
    augroup END
    call OmniSharp#popup#Map(mode, 'lineDown',     '<C-e>', "<SID>NvimPopupNormal('e', 1)")
    call OmniSharp#popup#Map(mode, 'lineUp',       '<C-y>', "<SID>NvimPopupNormal('y', 1)")
    call OmniSharp#popup#Map(mode, 'halfPageDown', '<C-d>', "<SID>NvimPopupNormal('d', 1)")
    call OmniSharp#popup#Map(mode, 'halfPageUp',   '<C-u>', "<SID>NvimPopupNormal('u', 1)")
    call OmniSharp#popup#Map(mode, 'pageDown',     '<C-f>', "<SID>NvimPopupNormal('f', 1)")
    call OmniSharp#popup#Map(mode, 'pageUp',       '<C-b>', "<SID>NvimPopupNormal('b', 1)")
  else
    let popupOpts = s:GetVimOptions(a:opts)
    let popupOpts.callback = function('s:Unmap')
    let s:lastwinid = popup_atcursor(a:what, popupOpts)
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

" Editing buffers is not allowed from <expr> mappings. The popup mappings are
" all <expr> mappings so they can be used consistently across modes, so instead
" of running the functions directly, they are run in an immediately executed
" timer callback.
function! s:PopupMapWrapper(funcall) abort
  execute printf('call timer_start(0, {-> %s})', a:funcall)
  return "\<Ignore>"
endfunction

" Neovim scrolling works by giving focus to the popup and running normal-mode
" commands
function! s:NvimPopupNormal(commands, wrapWithCtrl)
  call nvim_set_current_win(s:lastwinid)
  if a:wrapWithCtrl
    execute 'normal!' eval(printf('"\<C-%s>"', a:commands))
  else
    execute 'normal!' a:commands
  endif
  call nvim_set_current_win(s:parentwinid)
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
