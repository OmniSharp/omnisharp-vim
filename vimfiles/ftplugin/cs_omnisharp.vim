
"Set a default value for the server address
if !exists('g:OmniSharp_host')
	let g:OmniSharp_host='http://localhost:2000'
endif


autocmd BufWritePre <buffer> call OmniSharp#FindSyntaxErrors() 



let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
let g:SuperTabClosePreviewOnPopupClose = 1

setlocal omnifunc=OmniSharp#Complete
setlocal completefunc=OmniSharp#Complete
"don't autoselect first item in omnicomplete,show if only one item(for preview)
set completeopt=longest,menuone,preview
