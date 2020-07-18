let s:save_cpo = &cpoptions
set cpoptions&vim

function! OmniSharp#actions#fold#Create() abort
  if !g:OmniSharp_server_stdio
    echomsg 'This functionality is only available with the stdio server'
  endif
  call OmniSharp#actions#codestructure#Get(bufnr('%'), 1,
  \ function('s:CreateFolds'))
endfunction

function! s:CreateFolds(bufnr, codeElements) abort
  if a:bufnr != bufnr('%') | return | endif
  setlocal foldmethod=manual
  normal! zE
  for range in reverse(s:FindBlocks(a:codeElements))
    execute printf('%d,%dfold', range[0], range[1])
  endfor
endfunction

function! s:FindBlocks(codeElements) abort
  if type(a:codeElements) != type([]) | return [] | endif
  let ranges = []
  for element in a:codeElements
    if get(element, 'Kind', '') !=# 'namespace'
      if has_key(element, 'Ranges') && has_key(element.Ranges, 'full')
        let full = element.Ranges.full
        let start = get(get(full, 'Start', {}), 'Line', 0)
        let end = get(get(full, 'End', {}), 'Line', 0)
        if end - start >= &foldminlines
          call add(ranges, [start, end])
        endif
      endif
    endif
    call extend(ranges, s:FindBlocks(get(element, 'Children', [])))
  endfor
  return ranges
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
