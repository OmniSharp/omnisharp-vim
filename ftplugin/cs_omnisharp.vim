
"Set a default value for the server address
if !exists('g:OmniSharp_host')
	let g:OmniSharp_host='http://localhost:2000'
endif


" Auto syntax check.
autocmd BufWritePre <buffer>
\	if g:OmniSharp_BufWritePreSyntaxCheck
\|		let b:OmniSharp_SyntaxChecked = 1
\|		call OmniSharp#FindSyntaxErrors()
\|	else
\|		let b:OmniSharp_SyntaxChecked = 0
\|	endif

autocmd CursorHold <buffer>
\	if g:OmniSharp_CursorHoldSyntaxCheck && !get(b:, "OmniSharp_SyntaxChecked", 0)
\|		let b:OmniSharp_SyntaxChecked = 1
\|		call OmniSharp#FindSyntaxErrors()
\|	endif


let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
let g:SuperTabClosePreviewOnPopupClose = 1

setlocal omnifunc=OmniSharp#Complete
"don't autoselect first item in omnicomplete,show if only one item(for preview)
set completeopt=longest,menuone,preview
