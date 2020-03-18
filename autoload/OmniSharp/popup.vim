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
    let popup_opts = s:GetVimOptions(a:opts)
    if has_key(popup_opts, 'filter')
      unlet popup_opts.filter
    endif
    call popup_setoptions(a:opts.winid, popup_opts)
    call popup_settext(a:opts.winid, split(a:content, "\n"))
    if !popup_getpos(a:opts.winid).visible
      call popup_show(a:opts.winid)
    endif
    return a:opts.winid
  else
    return s:Open(content, a:opts)
  endif
endfunction

" Create a temporary, buffer-local mapping if a buffer-local lhs does not
" already exist. The mapping will be removed as soon as the popup window is
" closed.
function! OmniSharp#popup#Map(mode, lhs, funcall) abort
  if !get(maparg(a:lhs, a:mode, 0, 1), 'buffer', 0)
    execute printf('%snoremap <buffer> <nowait> <expr> %s <SID>PopupMapWrapper("%s")',
    \ a:mode, a:lhs, a:funcall)
    call add(s:popupmaps, [a:mode, a:lhs])
  endif
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
    for popupmap in get(s:, 'popupmaps', [])
      try
        execute popupmap[0] . 'unmap <buffer>' popupmap[1]
      catch | endtry
    endfor
    let s:popupmaps = []
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
  let popup_opts = copy(g:OmniSharp_popup_opts)
  if len(keys(a:opts))
    call extend(popup_opts, a:opts)
  endif
  return popup_opts
endfunction

function s:Open(what, opts) abort
  call s:CloseLast(0)
  let s:popupmaps = []
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
    let parentwinnr = win_getid(winnr())
    if has_key(a:opts, 'firstline')
      call s:NvimPopupNormal(a:opts.firstline . 'Gzt', 0, parentwinnr)
    endif
    call nvim_win_set_option(s:lastwinid, 'wrap', v:true)
    augroup OmniSharp_nvim_popup
      autocmd CursorMoved <buffer> call s:CloseLastNvimOnMove()
      autocmd CursorMovedI <buffer> call s:CloseLastNvimOnMove()
    augroup END
    for key in ['e', 'y', 'd', 'u', 'f', 'b']
      call OmniSharp#popup#Map(
      \ mode,
      \ printf('<C-%s>', key),
      \ printf("<SID>NvimPopupNormal('%s', 1, %d)", key, parentwinnr))
    endfor
  else
    let s:lastwinid = popup_atcursor(a:what, s:GetVimOptions(a:opts))
    call OmniSharp#popup#Map(mode, '<C-e>', '<SID>VimPopupScrollLine(1)')
    call OmniSharp#popup#Map(mode, '<C-y>', '<SID>VimPopupScrollLine(-1)')
    call OmniSharp#popup#Map(mode, '<C-d>', '<SID>VimPopupScrollPage(0.5)')
    call OmniSharp#popup#Map(mode, '<C-u>', '<SID>VimPopupScrollPage(-0.5)')
    call OmniSharp#popup#Map(mode, '<C-f>', '<SID>VimPopupScrollPage(1)')
    call OmniSharp#popup#Map(mode, '<C-b>', '<SID>VimPopupScrollPage(-1)')
  endif
  call OmniSharp#popup#Map(mode, '<Esc>', '<SID>CloseLast(1)')
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
function! s:NvimPopupNormal(commands, wrapWithCtrl, parentwinnr)
  call nvim_set_current_win(s:lastwinid)
  if a:wrapWithCtrl
    execute 'normal!' eval(printf('"\<C-%s>"', a:commands))
  else
    execute 'normal!' a:commands
  endif
  call nvim_set_current_win(a:parentwinnr)
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


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
