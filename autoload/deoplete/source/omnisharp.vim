
function! deoplete#source#omnisharp#receiveResponse(results)
  let g:deoplete#source#omnisharp#_results = a:results
  let g:deoplete#source#omnisharp#_receivedResults = v:true

  call deoplete#auto_complete()
endfunction

function! deoplete#source#omnisharp#sendRequest()
    " Send an empty string as partial because deoplete does its own fuzzy matching
    call OmniSharp#actions#complete#Get('', function('deoplete#source#omnisharp#receiveResponse'))
endfunction


