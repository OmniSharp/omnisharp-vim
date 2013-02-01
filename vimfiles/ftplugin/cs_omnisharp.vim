let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
let g:SuperTabClosePreviewOnPopupClose = 1

setlocal omnifunc=OmniSharp
set completeopt=longest,menuone,preview "don't autoselect first item in omnicomplete,show if only one item(for preview)
function! OmniSharp(findstart, base)
     if a:findstart
		 let g:textBuffer = getline(1,'$')
		 let g:cursorPosition = line2byte(line("."))+col(".") - 2
		 "locate the start of the word
		 let line = getline('.')
		 let start = col(".") - 1
		 while start > 0 && line[start - 1] =~ '\v[a-zA-z_]' 
			 let start -= 1
		 endwhile   

		 return start
     else
         let res = []
:python << EOF
import vim, urllib2, urllib, httplib, logging, sys, json
parameters = {}
parameters['cursorPosition'] = vim.eval("g:cursorPosition")
parameters['wordToComplete'] = vim.eval("a:base")
parameters['buffer'] = '\r\n'.join(vim.eval('g:textBuffer')[:])
parameters['filename'] = vim.current.buffer.name

logger = logging.getLogger('omnisharp')
hdlr = logging.FileHandler('c:\python.log')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr) 
logger.setLevel(logging.WARNING)

target = 'http://localhost:2000/autocomplete'

parameters = urllib.urlencode(parameters)
try:
	#proxy_handler = urllib2.ProxyHandler({'http': 'localhost:8888'})
	#opener = urllib2.build_opener(proxy_handler)
	#urllib2.install_opener(opener)
	response = urllib2.urlopen(target, parameters)
except:
	vim.command("call confirm('Could not connect to " + target + "')")

js = response.read()
if(js != ''):
	completions = json.loads(js)
	for completion in completions:
		try:
			command = "add(res, {'word': '%(CompletionText)s', 'abbr': '%(DisplayText)s', 'info': \"%(Description)s\", 'icase': 1, 'dup':1 })" % completion
			vim.eval(command)
		except:
			logger.error(command)
			
EOF
         return res
     endif
endfunction 
