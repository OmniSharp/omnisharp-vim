import vim, urllib2, urllib, urlparse, json

def get_response(endPoint, params=None, timeout=None):
    parameters = {}
    parameters['line'] = vim.eval('line(".")')
    parameters['column'] = vim.eval('col(".")')
    parameters['buffer'] = '\r\n'.join(vim.eval("getline(1,'$')")[:])
    parameters['filename'] = vim.current.buffer.name

    if params is not None:
        parameters.update(params)

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
    except Exception:
        vim.command("let g:serverSeenRunning = 0")
        return None

    json_string = response.read()
    if json_string.startswith("\xef\xbb\xbf"):  # Drop UTF-8 BOM
        json_string = json_string[3:]
    return  json.loads(json_string)
