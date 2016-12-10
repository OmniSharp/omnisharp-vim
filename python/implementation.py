#!/usr/bin/env python2
# -*- coding: utf-8 -*-

from __future__ import print_function

import json
import sys

if sys.version_info >= (3, 0):
    from urllib.parse import urljoin
    from urllib import request
elif sys.version_info < (3, 0) and sys.version_info >= (2, 5):
    import urllib2 as request
    from urlparse import urljoin
else:
    raise ImportError("Unsupported python version: {}".format(sys.version_info))


class OmniSharpOptions(object):
    '''An object which is only used to get settings of the plugin or the
    editor.'''
    def __init__(self, vim):
        self.vim = vim

    @property
    def host(self):
        if self.vim.eval('exists("b:OmniSharp_host")') == '1':
            return self.vim.eval('b:OmniSharp_host')

        return self.vim.eval('g:OmniSharp_host')

    @property
    def timeout(self):
        return int(self.vim.eval('g:OmniSharp_timeout'))

    @property
    def quickfixes_max(self):
        return int(self.vim.eval('g:OmniSharp_quickFixLength'))

    @property
    def include_documentation(self):
        return self.vim.eval('a:includeDocumentation')

    @property
    def expand_tab(self):
        return bool(int(self.vim.eval('&expandtab')))

    @property
    def default_quickfix_parameters(self):
        return {'MaxWidth': self.quickfixes_max}

class OmniSharp(object):
    '''Main plugin object, which will be defined as a singleton.
    '''
    def __init__(self, vim):
        self.vim = vim
        self._options = OmniSharpOptions(vim)

    @property
    def _default_parameters(self):
        parameters = {}
        parameters['line'] = self.vim.eval('line(".")')
        parameters['column'] = self.vim.eval('col(".")')
        parameters['buffer'] = '\r\n'.join(self.vim.eval("getline(1,'$')")[:])
        parameters['filename'] = self.vim.current.buffer.name
        return parameters

    def getResponse(self, endPoint, additional_parameters=None, timeout=None):
        parameters = self._default_parameters

        if additional_parameters is not None:
            parameters.update(additional_parameters)

        if timeout is None:
            timeout = self._options.timeout

        target = urljoin(self._options.host, endPoint)

        try:
            res = make_request(target, parameters, timeout)
            self.vim.command("let g:serverSeenRunning = 1")
            return res
        except Exception as e:
            self.vim.command("let g:serverSeenRunning = 0")
            # FIXME: should return None to differentiate between response and
            # no response
            return ''

    def get_json(self, end_point, additional_parameters=None, timeout=None):
        '''A wrapper to get json straight away'''
        response = self.getResponse(end_point, additional_parameters, timeout=None)
        if response is not None and response != '':
            return json.loads(response)

    def findUsages(self):
        parameters = self._options.default_quickfix_parameters
        js = self.get_json('/findusages', parameters)
        return parse_quickfix_response(js, 'QuickFixes')

    def findMembers(self):
        parameters = self._options.default_quickfix_parameters
        js = self.get_json('/currentfilemembersasflat', parameters)
        return parse_quickfixes(js)

    def findImplementations(self):
        parameters = self._options.default_quickfix_parameters
        js = self.get_json('/findimplementations', parameters)
        return parse_quickfix_response(js, 'QuickFixes')

    def gotoDefinition(self):
        definition = self.get_json('/gotodefinition')
        if definition is None:
            return

        if definition['FileName'] is not None:
            self.open_file(
                definition['FileName'].replace("'","''"),
                definition['Line'],
                definition['Column'])
        else:
            print("Not found")

    def open_file(self, filename, line, column):
        '''Open a file'''
        self.vim.command(
            "call OmniSharp#JumpToLocation('{filename}', {line}, {column})"
            .format(
                filename=filename,
                line=line,
                column=column))

    def getCodeActions(self, mode):
        parameters = self._get_code_action_parameters(mode)
        response = self.get_json('/getcodeactions', parameters)
        return [] if response is None else response['CodeActions']

    def runCodeAction(self, mode, action):
        parameters = self._get_code_action_parameters(mode)
        parameters['codeaction'] = action
        text = self.get_json('/runcodeaction', parameters)['Text']
        self.setBufferText(text)
        return True

    def _get_code_action_parameters(self, mode):
        if mode != 'visual':
            return {}

        start = self.vim.eval('getpos("\'<")')
        end = self.vim.eval('getpos("\'>")')

        return {
            'SelectionStartLine': start[1],
            'SelectionStartColumn': start[2],
            'SelectionEndLine': end[1],
            'SelectionEndColumn': end[2]
        }

    def setBufferText(self, text):
        if text == None:
            return
        lines = text.splitlines()

        cursor = self.vim.current.window.cursor
        lines = [line.encode('utf-8') for line in lines]
        self.vim.current.buffer[:] = lines
        self.vim.current.window.cursor = cursor

    def fixCodeIssue(self):
        text = self.get_json('/fixcodeissue')['Text']
        self.setBufferText(text)

    def getCodeIssues(self):
        js = self.get_json('/getcodeissues')
        return parse_quickfix_response(js, 'QuickFixes')

    def codeCheck(self):
        js = self.get_json('/codecheck')
        return parse_quickfix_response(js, 'QuickFixes')

    def typeLookup(self, ret):
        # FIXME: the logic could be simplified here as well
        parameters = {
            'includeDocumentation': self._options.include_documentation
        }
        response = self.get_json('/typelookup', parameters)

        if response is None:
            return

        type = response['Type']
        documentation = response['Documentation']
        if(documentation == None):
            documentation = ''
        if(type != None):
            self.vim.command("let %s = '%s'" % (ret, type))
            self.vim.command("let s:documentation = '%s'" % documentation.replace("'", "''"))

    def rename_to(self, new_name):
        return self.get_json('/rename', {'renameto': new_name})['Changes']

    def setBuffer(self, buffer):
        lines = buffer.splitlines()
        lines = [line.encode('utf-8') for line in lines]
        self.vim.current.buffer[:] = lines

    def build(self):
        response = self.get_json('/build', timeout=60)

        success = response["Success"]
        if success:
            print("Build succeeded")
        else:
            print("Build failed")

        return parse_quickfix_response(response, 'QuickFixes')

    @property
    def build_command(self):
        '''Return the build command'''
        return self.getResponse('/buildcommand')

    def get_test_command(self, mode):
        '''Return the test command'''
        parameters = {'Type': mode}
        response = self.get_json('/gettestcontext', parameters)
        return response['TestCommand']

    def codeFormat(self):
        parameters = {'ExpandTab': self._options.expand_tab}
        response = self.get_json('/codeformat', parameters)
        self.setBuffer(response["Buffer"])

    def fix_usings(self):
        js = self.get_json('/fixusings')
        self.setBuffer(js["Buffer"])
        return parse_quickfix_response(js, 'AmbiguousResults')

    def add_reference(self, reference):
        parameters = {"reference": reference}
        js = self.get_json("/addreference", parameters)
        if js is not None:
            print(js['Message'])

    def findSyntaxErrors(self):
        js = self.get_json('/syntaxerrors')
        return parse_quickfix_response(js, 'Errors')

    def findSemanticErrors(self):
        js = self.get_json('/semanticerrors')
        return parse_quickfix_response(js, 'Errors')

    def findTypes(self):
        js = self.get_json('/findtypes')
        return parse_quickfix_response(js, 'QuickFixes')

    def findSymbols(self):
        js = self.get_json('/findsymbols')
        return parse_quickfix_response(js, 'QuickFixes')

    def lookupAllUserTypes(self):
        response = self.get_json('/lookupalltypes')
        if response is not None:
            self.vim.command("let s:allUserTypes = '%s'" % (response['Types']))
            self.vim.command("let s:allUserInterfaces = '%s'" % (response['Interfaces']))

    def navigateUp(self):
        js = self.get_json('/navigateup')
        return parse_navigate_response(js)

    def navigateDown(self):
        js = self.get_json('/navigatedown')
        return parse_navigate_response(js)

def make_request(target, payload, timeout):
    '''Make request to the OmniSharp server'''
    proxy = request.ProxyHandler({})
    opener = request.build_opener(proxy)
    req = request.Request(target)
    req.add_header('Content-Type', 'application/json')

    json_ = json.dumps(payload).encode('utf-8')
    response = opener.open(req, json_, timeout)

    res = response.read()
    if res.startswith(b"\xef\xbb\xbf"):  # Drop UTF-8 BOM
        res = res[3:]

    return res.decode('utf-8')

def parse_navigate_response(response):
    if response is None:
        return {}
    else:
        return {'Line': response['Line'], 'Column': response['Column']}

def parse_quickfixes(response):
    '''Parse the quickfix list.'''
    if response is None or not isinstance(response, list):
        response = []

    items = []
    for quickfix in response:
        if 'Text' in quickfix:
            text = quickfix['Text']

        # FIXME: syntax errors returns 'Message' instead of 'Text'. I need to sort this out.
        if 'Message' in quickfix:
            text = quickfix['Message']

        item = {
            'filename': quickfix['FileName'],
            'text': text,
            'lnum': quickfix['Line'],
            'col': quickfix['Column'],
            'vcol': 0
        }
        items.append(item)

    return items

def parse_quickfix_response(response, key):
    '''Parse the quickfix response'''
    if response is None or key is None or not isinstance(response, dict):
        return []

    return parse_quickfixes(response.get(key, []))
