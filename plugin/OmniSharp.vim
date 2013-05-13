if exists("g:OmniSharp_loaded")
	finish
endif

let g:OmniSharp_loaded = 1

"Showmatch significantly slows down omnicomplete
"when the first match contains parentheses.
"Temporarily disable it
set noshowmatch
let s:omnisharp_path = expand('<sfile>:p:h')
"Load python/OmniSharp.py
let s:py_path = s:omnisharp_path
python << EOF
import vim, os.path
py_path = os.path.join(vim.eval("s:omnisharp_path"), "..", "python", "OmniSharp.py")
omnisharp_server = os.path.join(vim.eval("s:omnisharp_path"), "..", "server", "OmniSharp", "bin", "Debug", "OmniSharp.exe")
vim.command("let s:py_path = '" + py_path + "'")
vim.command("let s:omnisharp_server = '" + omnisharp_server + "'")
EOF
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

