import json, logging, os.path, platform, re, urllib2, urlparse, vim, socket
from contextlib import closing

logger = logging.getLogger('omnisharp')
logger.setLevel(logging.WARNING)

log_dir = os.path.join(vim.eval('expand("<sfile>:p:h")'), '..', 'log')
if not os.path.exists(log_dir):
    os.makedirs(log_dir)
hdlr = logging.FileHandler(os.path.join(log_dir, 'python.log'))
logger.addHandler(hdlr)

formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)

translate_unix_win = bool(int(vim.eval('g:OmniSharp_translate_cygwin_wsl')))
is_msys = 'msys_nt' in platform.system().lower()
is_cygwin = 'cygwin' in platform.system().lower()
is_wsl = 'linux' in platform.system().lower() and 'microsoft' in platform.release().lower()

# When working in Windows Subsystem for Linux (WSL) or Cygwin, vim uses
# unix-style paths but OmniSharp (with a Windows binary) uses Windows
# paths. This means that filenames returned FROM OmniSharp must be
# translated from e.g. "C:\path\to\file" to "/mnt/c/path/to/file", and
# filenames sent TO OmniSharp must be translated in the other direction.
def formatPathForServer(filepath):
    if translate_unix_win and (is_msys or is_cygwin or is_wsl):
        if is_msys:
            pattern = r'^/([a-zA-Z])/'
        elif is_cygwin:
            pattern = r'^/cygdrive/([a-zA-Z])/'
        else:
            pattern = r'^/mnt/([a-zA-Z])/'
        return re.sub(pattern, r'\1:\\', filepath).replace('/', '\\')
    return filepath
def formatPathForClient(filepath):
    if translate_unix_win and (is_msys or is_cygwin or is_wsl):
        def path_replace(matchobj):
            if is_msys:
                prefix = '/{0}/'
            elif is_cygwin:
                prefix = '/cygdrive/{0}/'
            else:
                prefix = '/mnt/{0}/'
            return prefix.format(matchobj.group(1).lower())
        return re.sub(r'^([a-zA-Z]):\\', path_replace, filepath).replace('\\', '/')
    return filepath

def getResponse(endPoint, additional_parameters=None, timeout=None):
    parameters = {}
    parameters['line'] = vim.eval('line(".")')
    parameters['column'] = vim.eval('col(".")')
    parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
    parameters['filename'] = formatPathForServer(vim.current.buffer.name)
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

def getCompletions(partialWord):
    parameters = {}
    parameters['column'] = vim.eval('col(".")')
    parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
    parameters['wordToComplete'] = partialWord

    parameters['WantDocumentationForEveryCompletionResult'] = \
        bool(int(vim.eval('g:omnicomplete_fetch_full_documentation')))

    want_snippet = \
        bool(int(vim.eval('g:OmniSharp_want_snippet')))

    parameters['WantSnippet'] = want_snippet
    parameters['WantMethodHeader'] = want_snippet
    parameters['WantReturnType'] = want_snippet

    response = json.loads(getResponse('/autocomplete', parameters))

    vim_completions = []
    if response != None:
        for completion in response:
            vim_completions.append({
                'snip': completion['Snippet'] or '',
                'word': completion['MethodHeader'] or completion['CompletionText'],
                'menu': completion['ReturnType'] or completion['DisplayText'],
                'info': (completion['Description'] or '').replace('\r\n', '\n'),
                'icase': 1,
                'dup': 1
            })
    return vim_completions

def gotoDefinition():
    js = getResponse('/gotodefinition');
    if js != '':
        definition = json.loads(js)
        if(definition['FileName'] != None):
            filename = formatPathForClient(definition['FileName'].replace("'","''"))
            openFile(filename, definition['Line'], definition['Column'])
        else:
            print("Not found")

def openFile(filename, line, column):
    vim.command("call OmniSharp#JumpToLocation('%(filename)s', %(line)s, %(column)s)" % locals())

def getCodeActions(mode, version='v1'):
    parameters = codeActionParameters(mode, version)
    if version == 'v1':
        endpoint = '/getcodeactions'
    elif version == 'v2':
        endpoint = '/v2/getcodeactions'
    js = getResponse(endpoint, parameters)
    if js != '':
        actions = json.loads(js)['CodeActions']
        return actions
    return []

def runCodeAction(mode, action, version='v1'):
    def __applyChange(changeDefinition):
        filename = formatPathForClient(changeDefinition['FileName'])
        openFile(filename, 1, 1)
        if __isBufferChange(changeDefinition):
            setBufferText(changeDefinition['Buffer'])
        elif __isNewFile(changeDefinition):
            for change in changeDefinition['Changes']:
                setBufferText(change['NewText'])

    def __isBufferChange(changeDefinition):
        return 'Buffer' in changeDefinition and changeDefinition['Buffer'] != None

    def __isNewFile(changeDefinition):
        return 'Changes' in changeDefinition and changeDefinition['Changes'] != None

    parameters = codeActionParameters(mode, version)
    if version == 'v1':
        parameters['codeaction'] = action
        res = getResponse('/runcodeaction', parameters)
        js = json.loads(res)
        if 'Text' in js:
            setBufferText(js['Text'])
            return True
    elif version == 'v2':
        parameters['identifier'] = action
        res = getResponse('/v2/runcodeaction', parameters)
        js = json.loads(res)
        if 'Changes' in js:
            vim.command("let cursor_position = getcurpos()")
            for changeDefinition in js['Changes']:
                __applyChange(changeDefinition)
            vim.command("call setpos('.', cursor_position)")
            return True
    return False

def codeActionParameters(mode, version='v1'):
    parameters = {}
    if mode == 'visual':
        start = vim.eval('getpos("\'<")')
        end = vim.eval('getpos("\'>")')
        if version == 'v1':
            parameters['SelectionStartLine'] = start[1]
            parameters['SelectionStartColumn'] = start[2]
            parameters['SelectionEndLine'] = end[1]
            parameters['SelectionEndColumn'] = end[2]
        elif version == 'v2':
            parameters['Selection'] = {
                'Start': { 'Line': start[1], 'Column': start[2] },
                'End': { 'Line': end[1], 'Column': end[2] }
            }
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
        print("Build succeeded")
    else:
        print("Build failed")

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
        print(message)

def findSyntaxErrors():
    js = getResponse('/syntaxerrors')
    return get_quickfix_list(js, 'Errors')

def findSemanticErrors():
    js = getResponse('/semanticerrors')
    return get_quickfix_list(js, 'Errors')

def findTypes():
    js = getResponse('/findtypes')
    return get_quickfix_list(js, 'QuickFixes')

def findSymbols(filter=''):
    parameters = {}
    parameters["filter"] = filter
    js = getResponse('/findsymbols', parameters)
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
        else:
            filename = formatPathForClient(filename)

        item = {
            'filename': filename,
            'text': text,
            'lnum': quickfix['Line'],
            'col': quickfix['Column'],
            'vcol': 0
        }
        if 'LogLevel' in quickfix:
            item['type'] = 'E' if quickfix['LogLevel'] == 'Error' else 'W'
            if quickfix['LogLevel'] == 'Hidden':
                item['subtype'] = 'Style'

        items.append(item)

    return items

def lookupAllUserTypes():
    js = getResponse('/findsymbols', {'filter': ''})
    if js != '':
        response = json.loads(js)
        if response != None and response['QuickFixes'] != None:
            slnTypes = []
            slnInterfaces = []
            slnAttributes = []
            for symbol in response['QuickFixes']:
                if symbol['Kind'] == 'Class':
                    slnTypes.append(symbol['Text'])
                    if symbol['Text'].endswith('Attribute'):
                        slnAttributes.append(symbol['Text'][:-9])
                elif symbol['Kind'] == 'Interface':
                    slnInterfaces.append(symbol['Text'])
            vim.command("let s:allUserTypes = '%s'" % ' '.join(slnTypes))
            vim.command("let s:allUserInterfaces = '%s'" % ' '.join(slnInterfaces))
            vim.command("let s:allUserAttributes = '%s'" % ' '.join(slnAttributes))

def lookupAllUserTypesLegacy():
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

def find_free_port():
    with closing(socket.socket(socket.AF_INET, socket.SOCK_STREAM)) as s:
        s.bind(('', 0))
        return s.getsockname()[1]
