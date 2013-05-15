if exists("g:OmniSharp_loaded")
	finish
endif

let g:OmniSharp_loaded = 1

"Load python/OmniSharp.py
let s:py_path = join([expand('<sfile>:p:h:h'), "python", "OmniSharp.py"], '/')
exec "pyfile " . fnameescape(s:py_path)

"Setup variable defaults
"Default value for the server address
if !exists('g:OmniSharp_host')
	let g:OmniSharp_host='http://localhost:2000'
endif

"Don't use the preview window by default
if !exists("g:OmniSharp_typeLookupInPreview")
	let g:OmniSharp_typeLookupInPreview = 0
endif


" Auto syntax-check options.
" Default:
" g:OmniSharp_BufWritePreSyntaxCheck = 1
" g:OmniSharp_CursorHoldSyntaxCheck  = 0
let g:OmniSharp_BufWritePreSyntaxCheck = get(g:, "OmniSharp_BufWritePreSyntaxCheck", 1)
let g:OmniSharp_CursorHoldSyntaxCheck = get(g:, "OmniSharp_CursorHoldSyntaxCheck", 0)


