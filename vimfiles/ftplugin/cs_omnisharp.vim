if exists("g:omnisharp_loaded")
 finish
endif
let g:omnisharp_loaded = 1

:python << EOF
import vim, urllib2, urllib, httplib, logging, sys, json
logger = logging.getLogger('omnisharp')
hdlr = logging.FileHandler('c:\python.log')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr) 
logger.setLevel(logging.WARNING)
EOF

let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
let g:SuperTabClosePreviewOnPopupClose = 1

set omnifunc=OmniSharp
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
parameters = {}
parameters['cursorPosition'] = vim.eval("g:cursorPosition")
parameters['wordToComplete'] = vim.eval("a:base")
parameters['buffer'] = '\r\n'.join(vim.eval('g:textBuffer')[:])
parameters['filename'] = vim.current.buffer.name

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

function! GotoDefinition()
:python << EOF
parameters = {}
parameters['line'] = vim.eval('line(".")')
parameters['column'] = vim.eval('col(".")')
parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
parameters['filename'] = vim.current.buffer.name

target = 'http://localhost:2000/gotodefinition'

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

	definition = json.loads(js)
	filename = definition['FileName']
	if(filename != None):
		if(filename != vim.current.buffer.name):
			vim.command('e ' + definition['FileName'])
		#row is 1 based, column is 0 based
		vim.current.window.cursor = (definition['Line'], definition['Column'] - 1 )
EOF

endfunction

function! FindUsages()
let qf_taglist = []
:python << EOF
parameters = {}
parameters['line'] = vim.eval('line(".")')
parameters['column'] = vim.eval('col(".")')
parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
parameters['filename'] = vim.current.buffer.name

target = 'http://localhost:2000/findusages'

parameters = urllib.urlencode(parameters)
try:
	response = urllib2.urlopen(target, parameters)
except:
	vim.command("call confirm('Could not connect to " + target + "')")

js = response.read()
if(js != ''):
	usages = json.loads(js)['Usages']

	for usage in usages:
		try:
			command = "add(qf_taglist, {'filename': '%(FileName)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})" % usage
			vim.eval(command)
		except:
			logger.error(command)
EOF

" Place the tags in the quickfix window, if possible
if len(qf_taglist) > 0
	call setqflist(qf_taglist)
	copen
else
	echo "No usages found"
endif
endfunction

function! FindImplementations()
let qf_taglist = []
:python << EOF
parameters = {}
parameters['line'] = vim.eval('line(".")')
parameters['column'] = vim.eval('col(".")')
parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
parameters['filename'] = vim.current.buffer.name

target = 'http://localhost:2000/findimplementations'

parameters = urllib.urlencode(parameters)
try:
	response = urllib2.urlopen(target, parameters)
except:
	vim.command("call confirm('Could not connect to " + target + "')")

js = response.read()
if(js != ''):
	usages = json.loads(js)['Locations']

	if(len(usages) == 1):
		usage = usages[0]
		filename = usage['FileName']
		if(filename != None):
			if(filename != vim.current.buffer.name):
				vim.command('e ' + usage['FileName'])
			#row is 1 based, column is 0 based
			vim.current.window.cursor = (usage['Line'], usage['Column'] - 1 )
	else:
		for usage in usages:
			try:
				command = "add(qf_taglist, {'filename': '%(FileName)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})" % usage
				vim.eval(command)
			except:
				logger.error(command)
EOF

" Place the tags in the quickfix window, if possible
if len(qf_taglist) > 1
	call setqflist(qf_taglist)
	copen 4
endif
endfunction
