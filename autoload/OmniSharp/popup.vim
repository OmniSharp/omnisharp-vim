let s:save_cpo = &cpoptions
set cpoptions&vim

let g:OmniSharp_popup_opts = get(g:, 'OmniSharp_popup_opts', {
\ 'padding': [0,1,1,1],
\ 'border': [1,0,0,0],
\ 'borderchars': [' '],
\ 'mapping': v:false,
\ 'scrollbar': v:true,
\ 'filter': function('OmniSharp#popup#FilterStandard')
\})

function OmniSharp#popup#FilterStandard(winid, key) abort
  " TODO: All of these filter keys should be be customisable
  if a:key ==# "\<Esc>"
    call popup_close(a:winid)
  elseif a:key ==# "\<C-e>" " Scroll line down
    call s:ScrollLine(a:winid, 1)
  elseif a:key ==# "\<C-y>" " Scroll line up
    call s:ScrollLine(a:winid, -1)
  elseif a:key ==# "\<C-d>" " Scroll half-page down
    call s:ScrollPage(a:winid, 0.5)
  elseif a:key ==# "\<C-u>" " Scroll half-page up
    call s:ScrollPage(a:winid, -0.5)
  elseif a:key ==# "\<C-f>" " Scroll page down
    call s:ScrollPage(a:winid, 1)
  elseif a:key ==# "\<C-b>" " Scroll page up
    call s:ScrollPage(a:winid, -1)
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
  return s:Open(content, a:opts)
endfunction


function s:CloseLast() abort
  if exists('s:lastwinid')
    call popup_close(s:lastwinid)
    unlet s:lastwinid
  endif
endfunction

function s:Open(what, opts) abort
  call s:CloseLast()
  let popup_opts = copy(g:OmniSharp_popup_opts)
  if len(keys(a:opts))
    call extend(popup_opts, a:opts)
  endif
  let s:lastwinid = popup_atcursor(a:what, popup_opts)
  return s:lastwinid
endfunction


" Popup scrolling functions by @bfrg from https://github.com/vim/vim/issues/5170
function! s:ScrollLine(winid, step) abort
    let line = popup_getoptions(a:winid).firstline
    if a:step < 0
        let newline = (line + a:step) > 0 ? (line + a:step) : 1
    else
        let nlines = line('$', a:winid)
        let newline = (line + a:step) <= nlines ? (line + a:step) : nlines
    endif
    call popup_setoptions(a:winid, {'firstline': newline})
endfunction

function! s:ScrollPage(winid, size) abort
    let height = popup_getpos(a:winid).core_height
    let step = float2nr(height * a:size)
    call s:ScrollLine(a:winid, step)
endfunction


let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
