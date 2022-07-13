let s:currentLhsRequest = v:null

function! s:onReceivedResponse(lhs, results) abort
  if s:currentLhsRequest != a:lhs
    return
  endif

  let g:deoplete#source#omnisharp#_results = a:results
  call deoplete#auto_complete()
endfunction

function! deoplete#source#omnisharp#sendRequest(lhs, partial) abort
  let s:currentLhsRequest = a:lhs
  let g:deoplete#source#omnisharp#_results = v:null
  let opts = {
  \ 'Callback': {results -> s:onReceivedResponse(a:lhs, results)}
  \}
  call OmniSharp#actions#complete#Get(a:partial, opts)
endfunction
