import vim, urllib2, urllib, urlparse, logging, json, os, os.path, cgi, types
from BaseHTTPServer import BaseHTTPRequestHandler, HTTPServer
from SocketServer import ThreadingMixIn


logger = logging.getLogger('omnisharp')
logger.setLevel(logging.WARNING)

log_dir = os.path.join(vim.eval('expand("<sfile>:p:h")'), '..', 'log')
if not os.path.exists(log_dir):
    os.makedirs(log_dir)
hdlr = logging.FileHandler(os.path.join(log_dir, 'python.log'))
logger.addHandler(hdlr) 

formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)


def getResponse(endPoint, additionalParameters=None, timeout=None ):
    parameters = {}
    parameters['line'] = vim.eval('line(".")')
    parameters['column'] = vim.eval('col(".")')
    parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
    parameters['filename'] = vim.current.buffer.name
    if(additionalParameters != None):
        parameters.update(additionalParameters)

    if(timeout == None):
        timeout=int(vim.eval('g:OmniSharp_timeout'))

    host = vim.eval('g:OmniSharp_host')

    if vim.eval('exists("b:OmniSharp_host")') == '1':
        host = vim.eval('b:OmniSharp_host')

    target = urlparse.urljoin(host, endPoint)
    parameters = urllib.urlencode(parameters)

    proxy = urllib2.ProxyHandler({})
    opener = urllib2.build_opener(proxy)
    try:
        response = opener.open(target, parameters, timeout)
        vim.command("let g:serverSeenRunning = 1")
        return response.read()
    except Exception as e:
        vim.command("let g:serverSeenRunning = 0")
        return ''


#All of these functions take vim variable names as parameters
def getCompletions(ret, column, partialWord):
    parameters = {}
    parameters['column'] = vim.eval(column)
    parameters['wordToComplete'] = vim.eval(partialWord)

    parameters['WantDocumentationForEveryCompletionResult'] = bool(int(vim.eval('g:omnicomplete_fetch_full_documentation')))
    parameters['buffer'] = '\r\n'.join(vim.eval('s:textBuffer')[:])
    js = getResponse('/autocomplete', parameters)

    command_base = ("add(" + ret +
            ", {'word': '%(CompletionText)s', 'menu': '%(DisplayText)s', 'info': \"%(Description)s\", 'icase': 1, 'dup':1 })")
    enc = vim.eval('&encoding')
    if(js != ''):
        completions = json.loads(js)
        for completion in completions:
            try:
                completion['Description'] = completion['Description'].replace('\r\n', '\n')
                command = command_base % completion
                if type(command) == types.StringType:
                    vim.eval(command)
                else:
                    vim.eval(command.encode(enc))
            except:
                logger.error(command)

def findUsages(ret):
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    js = getResponse('/findusages', parameters)
    if(js != ''):
        usages = json.loads(js)['QuickFixes']
        populateQuickFix(ret, usages)

def populateQuickFix(ret, quickfixes):
    command_base = ("add(" + ret + ", {'filename': '%(FileName)s', 'text': '%(Text)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})")
    if(quickfixes != None):
        for quickfix in quickfixes:
            quickfix["FileName"] = os.path.relpath(quickfix["FileName"])
            try:
                command = command_base % quickfix
                vim.eval(command)
            except:
                logger.error(command)

def findMembers(ret):
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    js = getResponse('/currentfilemembersasflat',parameters)
    if(js != ''):
        quickfixes = json.loads(js)
        populateQuickFix(ret, quickfixes)

def findImplementations(ret):
    js = getResponse('/findimplementations')
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    js = getResponse('/findimplementations',parameters)
    if(js != ''):
        usages = json.loads(js)['QuickFixes']

        command_base = ("add(" + ret + 
                ", {'filename': '%(FileName)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})")
        if(len(usages) == 1):
            usage = usages[0]
            openFile(usage['FileName'], usage['Line'], usage['Column'])
        else:
            populateQuickFix(ret, usages)

def gotoDefinition():
    js = getResponse('/gotodefinition');
    if(js != ''):
        definition = json.loads(js)
        if(definition['FileName'] != None):
            openFile(definition['FileName'], definition['Line'], definition['Column'])
        else:
            print "Not found"

def openFile(filename, line, column):
    filename = "'%(filename)s'" % locals() 
    vim.command('call OmniSharp#JumpToLocation(%(filename)s, %(line)s, %(column)s)' % locals())

def getCodeActions():
    js = getResponse('/getcodeactions')
    if(js != ''):
        actions = json.loads(js)['CodeActions']
        for index, action in enumerate(actions):
            print "%d :  %s" % (index, action)
        if len(actions) > 0:
            return True
    return False

def runCodeAction(option):
    parameters = {}
    parameters['codeaction'] = vim.eval(option)
    js = getResponse('/runcodeaction', parameters);
    text = json.loads(js)['Text']
    if(text == None):
        return
    lines = text.splitlines()

    cursor = vim.current.window.cursor
    lines = [line.encode('utf-8') for line in lines]
    vim.current.buffer[:] = lines
    vim.current.window.cursor = cursor

def findSyntaxErrors(ret):
    js = getResponse('/syntaxerrors')
    if(js != ''):
        errors = json.loads(js)['Errors']

        command_base = ("add(" + ret +
                ", {'filename': '%(FileName)s', 'text': '%(Message)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})")
        for err in errors:
            try:
                command = command_base % err
                vim.eval(command)
            except:
                logger.error(command)

def typeLookup(ret):
    parameters = {} 
    parameters['includeDocumentation'] = vim.eval('a:includeDocumentation')
    js = getResponse('/typelookup', parameters);
    if(js != ''):
        response = json.loads(js)
        type = response['Type']
        documentation = response['Documentation']
        if(documentation == None):
            documentation = ''
        if(type != None):
            vim.command("let %s = '%s'" % (ret, type)) 
            vim.command("let s:documentation = '%s'" % documentation) 

def renameTo(renameTo):
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

def setBuffer(buffer):
    lines = buffer.splitlines()
    lines = [line.encode('utf-8') for line in lines]
    vim.current.buffer[:] = lines

def build(ret):
    response = json.loads(getResponse('/build', {}, 60))

    success = response["Success"]
    if success:
        print "Build succeeded"
    else:
        print "Build failed"

    quickfixes = response['QuickFixes']
    populateQuickFix(ret, quickfixes)

def buildcommand():
    vim.command("let b:buildcommand = '%s'" % getResponse('/buildcommand')) 

def getTestCommand():
    mode = vim.eval('a:mode')
    parameters = {}
    parameters['Type'] = mode
    response = json.loads(getResponse('/gettestcontext', parameters))
    testCommand = "let s:testcommand = '%(TestCommand)s'" % response
    vim.command(testCommand)
		
def codeFormat():
    parameters = {}
    parameters['ExpandTab'] = bool(int(vim.eval('&expandtab')))
    response = json.loads(getResponse('/codeformat', parameters))
    setBuffer(response["Buffer"])

def addReference():
    parameters = {}
    parameters["reference"] = vim.eval("a:ref")
    js = getResponse("/addreference", parameters)
    if(js != ''):
        message = json.loads(js)['Message']
        print message

def findTypes():
    js = getResponse('/findtypes')
    findThings(js)

def findSymbols():
    js = getResponse('/findsymbols')
    findThings(js)

def findThings(js):
    if (js != ''):
        response = json.loads(js)
        if (response != None):
            quickfixes = response['QuickFixes']
            command_base = "{'filename': '%(FileName)s', 'text': '%(Text)s', 'lnum': '%(Line)s', 'col': '%(Column)s'}"
            l = []
            if(quickfixes != None):
                for quickfix in quickfixes:
                    quickfix["FileName"] = os.path.relpath(quickfix["FileName"])
                    l.append(command_base % quickfix)
                vim_quickfixes = "[" + ",".join(l) + "]"
                vim.command("let s:quickfixes = " + vim_quickfixes)

def lookupAllUserTypes():
    js = getResponse('/lookupalltypes')
    if (js != ''):
        response = json.loads(js)
        if (response != None):
            vim.command("let s:allUserTypes = '%s'" % (response['Types']))
            vim.command("let s:allUserInterfaces = '%s'" % (response['Interfaces']))

