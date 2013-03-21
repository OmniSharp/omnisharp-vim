if exists("g:OmniSharp_loaded")
	finish
endif

let g:OmniSharp_loaded = 1

"Set a default value for the server address
if !exists('g:OmniSharp_host')
	let g:OmniSharp_host='http://localhost:2000'
endif

autocmd BufWritePre *.cs call FindSyntaxErrors() 

:python << EOF
import vim, urllib2, urllib, urlparse, logging, json, os.path

logger = logging.getLogger('omnisharp')
hdlr = logging.FileHandler('python.log')
formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)
logger.addHandler(hdlr) 
logger.setLevel(logging.WARNING)

def getResponse(endPoint, additionalParameters=None):
	parameters = {}
	parameters['line'] = vim.eval('line(".")')
	parameters['column'] = vim.eval('col(".")')
	parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
	parameters['filename'] = vim.current.buffer.name

	if(additionalParameters != None):
		parameters.update(additionalParameters)

	target = urlparse.urljoin(vim.eval('g:OmniSharp_host'), endPoint)
	parameters = urllib.urlencode(parameters)
	try:
		response = urllib2.urlopen(target, parameters)
		return response.read()
	except:
		vim.command("call confirm('Could not connect to " + target + "')")
		return ''
EOF

let g:SuperTabDefaultCompletionType = 'context'
let g:SuperTabContextDefaultCompletionType = "<c-x><c-o>"
let g:SuperTabDefaultCompletionTypeDiscovery = ["&omnifunc:<c-x><c-o>","&completefunc:<c-x><c-n>"]
let g:SuperTabClosePreviewOnPopupClose = 1

set omnifunc=OmniSharp
set completeopt=longest,menuone,preview "don't autoselect first item in omnicomplete,show if only one item(for preview)
function! OmniSharp(findstart, base)
     if a:findstart
		 "store the current cursor position
		 let s:column = col(".")
		 "locate the start of the word
		 let line = getline('.')
		 let start = col(".") - 1
		 while start > 0 && line[start - 1] =~ '\v[a-zA-z0-9_]' 
			 let start -= 1
		 endwhile   

		 return start
     else
         let res = []
:python << EOF
parameters = {}
parameters['column'] = vim.eval("s:column")
parameters['wordToComplete'] = vim.eval("a:base")

js = getResponse('/autocomplete', parameters)
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
js = getResponse('/gotodefinition');
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

function! GetCodeActions()
:python << EOF
js = getResponse('/getcodeactions');
if(js != ''):
	actions = json.loads(js)['CodeActions']
	for index, action in enumerate(actions):
		vim.command('echo ' + str(index) + '":  ' + action + '"')
	if(len(actions) == 0):
		vim.command('return 1')
else:
	vim.command('return 1')
EOF

let a:option=nr2char(getchar())
if(a:option < '0' || a:option > '9')
	return 1
endif
:python << EOF
parameters = {}
parameters['codeaction'] = vim.eval("a:option")
js = getResponse('/runcodeaction', parameters);
text = json.loads(js)['Text']
if(text == None):
	vim.command('return 1')
lines = text.splitlines()

cursor = vim.current.window.cursor
vim.command('normal ggdG')
lines = [line.encode('utf-8') for line in lines]
vim.current.buffer[:] = lines
vim.current.window.cursor = cursor
EOF

endfunction

function! Rename()        
	let a:renameto = inputdialog("Rename to:")
	call RenameTo(a:renameto)
endfunction

function! RenameTo(renameto)        
let qf_taglist = []
:python << EOF
parameters = {}
parameters['renameto'] = vim.eval("a:renameto")

js = getResponse('/rename', parameters)
response = json.loads(js)
changes = response['Changes']
currentBuffer = vim.current.buffer.name
cursor = vim.current.window.cursor
for change in changes:
	lines = change['Buffer'].splitlines()
	lines = [line.encode('utf-8') for line in lines]
	filename = change['FileName']
	vim.command(':argadd ' + filename)
	buffer = filter(lambda b: b.name != None and b.name.upper() == filename.upper(), vim.buffers)[0]
	vim.command(':b ' + filename)
	buffer[:] = lines
	vim.command(':undojoin')

vim.command(':b ' + currentBuffer)
vim.current.window.cursor = cursor
#usages = response["Usages"]
#for usage in usages:
#	usage["FileName"] = os.path.relpath(usage["FileName"])
#	try:
#		command = "add(qf_taglist, {'filename': '%(FileName)s', 'text': '%(Text)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})" % usage
#		vim.eval(command)
#	except:
#		logger.error(command)
EOF
" Place the tags in the quickfix window, if possible
if len(qf_taglist) > 0
	call setqflist(qf_taglist)
	copen 4
else
	echo "No usages found"
endif    
endfunction

function! FindUsages()
let qf_taglist = []
:python << EOF
js = getResponse('/findusages')
if(js != ''):
	usages = json.loads(js)['Usages']

	for usage in usages:
		usage["FileName"] = os.path.relpath(usage["FileName"])
		try:
			command = "add(qf_taglist, {'filename': '%(FileName)s', 'text': '%(Text)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})" % usage
			vim.eval(command)
		except:
			logger.error(command)
EOF

" Place the tags in the quickfix window, if possible
if len(qf_taglist) > 0
	call setqflist(qf_taglist)
	copen 4
else
	echo "No usages found"
endif
endfunction

function! FindSyntaxErrors()
let qf_taglist = []
if bufname('%') == ''
	return
endif
:python << EOF
js = getResponse('/syntaxerrors')
if(js != ''):
	usages = json.loads(js)['Errors']

	for usage in usages:
		try:
			command = "add(qf_taglist, {'filename': '%(FileName)s', 'text': '%(Message)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})" % usage
			vim.eval(command)
		except:
			logger.error(command)
EOF

" Place the tags in the quickfix window, if possible
if len(qf_taglist) > 0
	call setqflist(qf_taglist)
	copen 4
else
	cclose
endif

endfunction
function! FindImplementations()
let qf_taglist = []
:python << EOF
js = getResponse('/findimplementations')
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
			usage["FileName"] = os.path.relpath(usage["FileName"])
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


function! TypeLookup()
:python << EOF
js = getResponse('/typelookup');
if(js != ''):

	type = json.loads(js)['Type']
	#filename = definition['FileName']
	if(type != None):
		print type
EOF

endfunction
