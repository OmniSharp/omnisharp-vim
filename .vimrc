" Supertab settings
let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
let g:SuperTabClosePreviewOnPopupClose = 1
set completeopt=longest,menuone,preview "don't autoselect first item in omnicomplete,show if only one item(for preview)

autocmd FileType cs setlocal omnifunc=OmniSharp
let g:partialWord= "none"
function! OmniSharp(findstart, base)
     if a:findstart
		 let g:partialWord= expand('<cword>')
		 "locate the start of the word
		 let line = getline('.')
		 let start = col(".") - 1
		 while start > 0 && line[start - 1] =~ '\v[a-zA-z_]' 
			 let start -= 1
		 endwhile
		 return start

     else
         let res = []
:ruby << EOF
require 'socket'

host = '127.0.0.1'
port = 2000

buffer = VIM::Buffer
body = []
cursorPosition = VIM::evaluate('line2byte(line("."))+col(".")') 
body << cursorPosition

body << VIM::evaluate('a:base') # the current word to be completed
body << buffer.current.name # filename
body <<  VIM::evaluate("getline(1,'$')")
request = body.join("\r\n")
socket = TCPSocket.open(host,port)  # Connect to the server
socket.print(request)               # Send request
response = socket.read              # Read complete response
commands = response.split  ("\n")
commands.each { |command| VIM::evaluate(command) }
EOF
         return res
     endif
endfunction
