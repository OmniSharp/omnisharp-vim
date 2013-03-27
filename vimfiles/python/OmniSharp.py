import vim, urllib2, urllib, urlparse, logging, json, os, os.path


logger = logging.getLogger('omnisharp')
logger.setLevel(logging.WARNING)

log_dir = os.path.join(vim.eval('expand("<sfile>:p:h")'), '..', 'log')
if not os.path.exists(log_dir):
    os.makedirs(log_dir)
hdlr = logging.FileHandler(os.path.join(log_dir, 'python.log'))
logger.addHandler(hdlr) 

formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
hdlr.setFormatter(formatter)

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


#All of these functions take vim variable names as parameters
def getCompletions(ret, column, partialWord):
    parameters = {}
    parameters['column'] = vim.eval(column)
    parameters['wordToComplete'] = vim.eval(partialWord)

    parameters['buffer'] = '\r\n'.join(vim.eval('s:textBuffer')[:])
    js = getResponse('/autocomplete', parameters)

    command_base = ("add(" + ret +
        ", {'word': '%(CompletionText)s', 'abbr': '%(DisplayText)s', 'info': \"%(Description)s\", 'icase': 1, 'dup':1 })")
    if(js != ''):
        completions = json.loads(js)
        for completion in completions:
            try:
                command = command_base % completion
                vim.eval(command)
            except:
                logger.error(command)

def findUsages(ret):
    js = getResponse('/findusages')
    if(js != ''):
        usages = json.loads(js)['Usages']

        command_base = ("add(" + ret +
            ", {'filename': '%(FileName)s', 'text': '%(Text)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})")
        for usage in usages:
            usage["FileName"] = os.path.relpath(usage["FileName"])
            try:
                command = command_base % usage
                vim.eval(command)
            except:
                logger.error(command)

def findImplementations(ret):
    js = getResponse('/findimplementations')
    if(js != ''):
        usages = json.loads(js)['Locations']

        command_base = ("add(" + ret + 
            ", {'filename': '%(FileName)s', 'lnum': '%(Line)s', 'col': '%(Column)s'})")
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
                    command = command_base % usage
                    vim.eval(command)
                except:
                    logger.error(command)

def gotoDefinition():
    js = getResponse('/gotodefinition');
    if(js != ''):

        definition = json.loads(js)
        filename = definition['FileName']
        if(filename != None):
            if(filename != vim.current.buffer.name):
                vim.command('e ' + definition['FileName'])
            #row is 1 based, column is 0 based
            vim.current.window.cursor = (definition['Line'], definition['Column'] - 1 )

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
    vim.command('normal ggdG')
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
    js = getResponse('/typelookup');
    if(js != ''):
        type = json.loads(js)['Type']
        if(type != None):
            vim.command("let %s = '%s'" % (ret, type)) 

