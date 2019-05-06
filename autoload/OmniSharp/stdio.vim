let s:save_cpo = &cpoptions
set cpoptions&vim

let s:requests = []

function! OmniSharp#stdio#HandleResponse(channelid, message) abort
  echom a:channelid . ' - ' . a:message
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
