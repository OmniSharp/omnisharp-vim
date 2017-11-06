import vim, urllib2, urllib, urlparse, logging, json, os, os.path, cgi, types, threading
import asyncrequest

logger = logging.getLogger('omnisharp')
logger.setLevel(logging.WARNING)

log_dir = os.path.join(vim.eval('expand("<sfile>:p:h")'), '..', 'log')
if not os.path.exists(log_dir):
    os.makedirs(log_dir)
hdlr = logging.FileHandler(os.path.join(log_dir, 'python.log'))
logger.addHandler(hdlr)

formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)


def getResponse(endPoint, additional_parameters=None, timeout=None):
    parameters = {}
    parameters['line'] = vim.eval('line(".")')
    parameters['column'] = vim.eval('col(".")')
    parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
    parameters['filename'] = vim.current.buffer.name
    if additional_parameters != None:
        parameters.update(additional_parameters)

    if timeout == None:
        timeout = int(vim.eval('g:OmniSharp_timeout'))

    host = vim.eval('g:OmniSharp_host')

    if vim.eval('exists("b:OmniSharp_host")') == '1':
        host = vim.eval('b:OmniSharp_host')

    target = urlparse.urljoin(host, endPoint)

    proxy = urllib2.ProxyHandler({})
    opener = urllib2.build_opener(proxy)
    req = urllib2.Request(target)
    req.add_header('Content-Type', 'application/json')

    try:
        response = opener.open(req, json.dumps(parameters), timeout)
        vim.command("let g:serverSeenRunning = 1")
        res = response.read()
        if res.startswith("\xef\xbb\xbf"):  # Drop UTF-8 BOM
            res = res[3:]
        return res
    except Exception:
        vim.command("let g:serverSeenRunning = 0")
        return ''

def findUsages():
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    js = getResponse('/findusages', parameters)
    return get_quickfix_list(js, 'QuickFixes')

def findMembers():
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    js = getResponse('/currentfilemembersasflat', parameters)
    return quickfixes_from_response(json.loads(js));

def findImplementations():
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    js = getResponse('/findimplementations', parameters)
    return get_quickfix_list(js, 'QuickFixes')

def gotoDefinition():
    js = getResponse('/gotodefinition');
    if(js != ''):
        definition = json.loads(js)
        if(definition['FileName'] != None):
            openFile(definition['FileName'].replace("'","''"), definition['Line'], definition['Column'])
        else:
            print "Not found"

def openFile(filename, line, column):
    vim.command("call OmniSharp#JumpToLocation('%(filename)s', %(line)s, %(column)s)" % locals())

def getCodeActions(mode):
    parameters = codeActionParameters(mode)
    js = getResponse('/getcodeactions', parameters)
    if js != '':
        actions = json.loads(js)['CodeActions']
        return actions
    return []

def runCodeAction(mode, action):
    parameters = codeActionParameters(mode)
    parameters['codeaction'] = action
    js = getResponse('/runcodeaction', parameters);
    text = json.loads(js)['Text']
    setBufferText(text)
    return True

def codeActionParameters(mode):
    parameters = {}
    if mode == 'visual':
        start = vim.eval('getpos("\'<")')
        end = vim.eval('getpos("\'>")')
        parameters['SelectionStartLine'] = start[1]
        parameters['SelectionStartColumn'] = start[2]
        parameters['SelectionEndLine'] = end[1]
        parameters['SelectionEndColumn'] = end[2]
    return parameters

def setBufferText(text):
    if text == None:
        return
    lines = text.splitlines()

    cursor = vim.current.window.cursor
    lines = [line.encode('utf-8') for line in lines]
    vim.current.buffer[:] = lines
    vim.current.window.cursor = cursor

def fixCodeIssue():
    js = getResponse('/fixcodeissue');
    text = json.loads(js)['Text']
    setBufferText(text)

def getCodeIssues():
    js = getResponse('/getcodeissues')
    return get_quickfix_list(js, 'QuickFixes')

def codeCheck():
    js = getResponse('/codecheck')
    return get_quickfix_list(js, 'QuickFixes')

def typeLookup(ret):
    parameters = {}
    parameters['includeDocumentation'] = vim.eval('a:includeDocumentation')
    js = getResponse('/typelookup', parameters);
    if js != '':
        response = json.loads(js)
        type = response['Type']
        documentation = response['Documentation']
        if(documentation == None):
            documentation = ''
        if(type != None):
            vim.command("let %s = '%s'" % (ret, type))
            vim.command("let s:documentation = '%s'" % documentation.replace("'", "''"))

def renameTo():
    parameters = {}
    parameters['renameto'] = vim.eval("a:renameto")
    js = getResponse('/rename', parameters)
    return js

def setBuffer(buffer):
    lines = buffer.splitlines()
    lines = [line.encode('utf-8') for line in lines]
    vim.current.buffer[:] = lines

def build():
    js = json.loads(getResponse('/build', {}, 60))

    success = js["Success"]
    if success:
        print "Build succeeded"
    else:
        print "Build failed"

    return quickfixes_from_js(js, 'QuickFixes')

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

def fix_usings():
    response = getResponse('/fixusings')
    js = json.loads(response)
    setBuffer(js["Buffer"])
    return get_quickfix_list(response, 'AmbiguousResults')

def addReference():
    parameters = {}
    parameters["reference"] = vim.eval("a:ref")
    js = getResponse("/addreference", parameters)
    if js != '':
        message = json.loads(js)['Message']
        print message

def findSyntaxErrors():
    js = getResponse('/syntaxerrors')
    return get_quickfix_list(js, 'Errors')

def findSemanticErrors():
    js = getResponse('/semanticerrors')
    return get_quickfix_list(js, 'Errors')

def findTypes():
    js = getResponse('/findtypes')
    return get_quickfix_list(js, 'QuickFixes')

def findSymbols():
    js = getResponse('/findsymbols')
    return get_quickfix_list(js, 'QuickFixes')

def get_quickfix_list(js, key):
    if js != '':
        response = json.loads(js)
        return quickfixes_from_js(response, key)
    return [];

def quickfixes_from_js(js, key):
    if js[key] is not None:
        return quickfixes_from_response(js[key])
    return [];

def quickfixes_from_response(response):
    items = []
    for quickfix in response:
        if 'Text' in quickfix:
            text = quickfix['Text']
        #syntax errors returns 'Message' instead of 'Text'. I need to sort this out.
        if 'Message' in quickfix:
            text = quickfix['Message']

        filename = quickfix['FileName']
        if filename == None:
            filename = vim.current.buffer.name

        item = {
            'filename': filename,
            'text': text,
            'lnum': quickfix['Line'],
            'col': quickfix['Column'],
            'vcol': 0
        }
        items.append(item)

    return items

def lookupAllUserTypes():
    js = getResponse('/lookupalltypes')
    if js != '':
        response = json.loads(js)
        if response != None:
            vim.command("let s:allUserTypes = '%s'" % (response['Types']))
            vim.command("let s:allUserInterfaces = '%s'" % (response['Interfaces']))

def navigateUp():
    js = getResponse('/navigateup')
    return get_navigate_response(js)

def navigateDown():
    js = getResponse('/navigatedown')
    return get_navigate_response(js)

def get_navigate_response(js):
    if js != '':
        response = json.loads(js)
        return {'Line': response['Line'], 'Column': response['Column']}
    else:
        return {}
