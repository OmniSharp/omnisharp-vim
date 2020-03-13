let s:save_cpo = &cpoptions
set cpoptions&vim

let g:OmniSharp_popup_opts = get(g:, 'OmniSharp_popup_opts', {
\ 'highlight': 'PMenu',
\ 'padding': [0,1,1,1],
\ 'border': [1,0,0,0],
\ 'borderchars': [' '],
\ 'mapping': v:true,
\ 'scrollbar': v:true,
\ 'filter': function('OmniSharp#popup#FilterStandard')
\})

function OmniSharp#popup#FilterStandard(winid, key) abort
  " TODO: All of these filter keys should be be customisable
  if a:key ==# "\<Esc>"
    call popup_close(a:winid)
  elseif a:key ==# "\<C-e>" " Scroll line down
    call s:VimPopupScrollLine(a:winid, 1)
  elseif a:key ==# "\<C-y>" " Scroll line up
    call s:VimPopupScrollLine(a:winid, -1)
  elseif a:key ==# "\<C-d>" " Scroll half-page down
    call s:VimPopupScrollPage(a:winid, 0.5)
  elseif a:key ==# "\<C-u>" " Scroll half-page up
    call s:VimPopupScrollPage(a:winid, -0.5)
  elseif a:key ==# "\<C-f>" " Scroll page down
    call s:VimPopupScrollPage(a:winid, 1)
  elseif a:key ==# "\<C-b>" " Scroll page up
    call s:VimPopupScrollPage(a:winid, -1)
  else
    return v:false
  endif
  return v:true
endfunction

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


function s:CloseLast() abort
  if exists('s:lastwinid')
    if has('nvim')
      call nvim_win_close(s:lastwinid, v:true)
      if exists('#OmniSharp_nvim_popup')
        autocmd! OmniSharp_nvim_popup
      endif
      if exists('s:mapped_esc')
        nunmap <buffer> <Esc>
        unlet s:mapped_esc
      endif
    else
      call popup_close(s:lastwinid)
    endif
    unlet s:lastwinid
  endif
endfunction

" Mimic Vim behaviour in neovim: close the window when the cursor is moved to a
" different line
function s:CloseLastNvimOnMove() abort
  if line('.') != s:lastwinpos[0]
    call s:CloseLast()
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
  call s:CloseLast()
  let s:lastwinpos = [line('.'), col('.')]
  if has('nvim')
    if type(a:what) == v:t_number
      let bufnr = a:what
    else
      let bufnr = nvim_create_buf(v:false, v:true)
      call setbufline(bufnr, 1, a:what)
    endif
    let s:lastwinid = nvim_open_win(bufnr, v:false, s:GetNvimOptions(a:opts))
    let winnr = win_getid(winnr())
    if has_key(a:opts, 'firstline')
      call nvim_set_current_win(s:lastwinid)
      execute 'normal!' a:opts.firstline . 'G'
      normal! zt
      call nvim_set_current_win(winnr)
    endif
    call nvim_win_set_option(s:lastwinid, 'wrap', v:true)
    if maparg('<Esc>', 'n') ==# ''
      let s:mapped_esc = 1
      nnoremap <silent> <buffer> <Esc> :call <SID>CloseLast()<CR>
    endif
    augroup OmniSharp_nvim_popup
      autocmd CursorMoved <buffer> call s:CloseLastNvimOnMove()
      autocmd CursorMovedI <buffer> call s:CloseLastNvimOnMove()
    augroup END
  else
    let s:lastwinid = popup_atcursor(a:what, s:GetVimOptions(a:opts))
  endif
  call s:CreatePopupMappings()
  return s:lastwinid
endfunction


" Popup scrolling functions by @bfrg from https://github.com/vim/vim/issues/5170
function! s:VimPopupScrollLine(winid, step) abort
  let line = popup_getoptions(a:winid).firstline
  if a:step < 0
    let newline = (line + a:step) > 0 ? (line + a:step) : 1
  else
    let nlines = line('$', a:winid)
    let newline = (line + a:step) <= nlines ? (line + a:step) : nlines
  endif
  call popup_setoptions(a:winid, {'firstline': newline})
endfunction

function! s:VimPopupScrollPage(winid, size) abort
  let height = popup_getpos(a:winid).core_height
  let step = float2nr(height * a:size)
  call s:VimPopupScrollLine(a:winid, step)
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
