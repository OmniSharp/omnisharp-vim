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


class OmniSharp(object):
    '''Main plugin object, which will be defined as a singleton.
    '''
    def __init__(self, vim):
        self.vim = vim

    def _request(self, target, payload, timeout):
        proxy = request.ProxyHandler({})
        opener = request.build_opener(proxy)
        req = request.Request(target)
        req.add_header('Content-Type', 'application/json')
        response = opener.open(req, json.dumps(payload).encode('utf-8'), timeout)
        res = response.read()
        if res.startswith(b"\xef\xbb\xbf"):  # Drop UTF-8 BOM
            res = res[3:]
        return res

    def getResponse(self, endPoint, additional_parameters=None, timeout=None):
        parameters = {}
        parameters['line'] = self.vim.eval('line(".")')
        parameters['column'] = self.vim.eval('col(".")')
        parameters['buffer'] = '\r\n'.join(self.vim.eval("getline(1,'$')")[:])
        parameters['filename'] = self.vim.current.buffer.name
        if additional_parameters != None:
            parameters.update(additional_parameters)

        if timeout == None:
            timeout = int(self.vim.eval('g:OmniSharp_timeout'))

        host = self.vim.eval('g:OmniSharp_host')

        if self.vim.eval('exists("b:OmniSharp_host")') == '1':
            host = self.vim.eval('b:OmniSharp_host')

        target = urljoin(host, endPoint)

        try:
            res = self._request(target, parameters, timeout)
            self.vim.command("let g:serverSeenRunning = 1")
            return res.decode('utf-8')
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
        parameters = {}
        parameters['MaxWidth'] = int(self.vim.eval('g:OmniSharp_quickFixLength'))
        js = self.get_json('/findusages', parameters)
        return parse_quickfix_response(js, 'QuickFixes')

    def findMembers(self):
        parameters = {}
        parameters['MaxWidth'] = int(self.vim.eval('g:OmniSharp_quickFixLength'))
        js = self.get_json('/currentfilemembersasflat', parameters)
        return parse_quickfix_response(js)

    def findImplementations(self):
        parameters = {}
        parameters['MaxWidth'] = int(self.vim.eval('g:OmniSharp_quickFixLength'))
        js = self.get_json('/findimplementations', parameters)
        return parse_quickfix_response(js, 'QuickFixes')

    def gotoDefinition(self):
        definition = self.get_json('/gotodefinition')
        if definition is not None:
            if definition['FileName'] is not None:
                self.openFile(definition['FileName'].replace("'","''"), definition['Line'], definition['Column'])
            else:
                print("Not found")

    def openFile(self, filename, line, column):
        self.vim.command("call OmniSharp#JumpToLocation('%(filename)s', %(line)s, %(column)s)" % locals())

    def getCodeActions(self, mode):
        parameters = self.codeActionParameters(mode)
        response = self.get_json('/getcodeactions', parameters)
        return [] if response is None else response['CodeActions']

    def runCodeAction(self, mode, action):
        parameters = self.codeActionParameters(mode)
        parameters['codeaction'] = action
        text = self.get_json('/runcodeaction', parameters)['Text']
        self.setBufferText(text)
        return True

    def codeActionParameters(self, mode):
        parameters = {}
        if mode == 'visual':
            start = self.vim.eval('getpos("\'<")')
            end = self.vim.eval('getpos("\'>")')
            parameters['SelectionStartLine'] = start[1]
            parameters['SelectionStartColumn'] = start[2]
            parameters['SelectionEndLine'] = end[1]
            parameters['SelectionEndColumn'] = end[2]
        return parameters

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
        parameters = {}
        parameters['includeDocumentation'] = self.vim.eval('a:includeDocumentation')
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

    def renameTo(self):
        parameters = {}
        parameters['renameto'] = self.vim.eval("a:renameto")
        return self.getResponse('/rename', parameters)

    def setBuffer(self, buffer):
        lines = buffer.splitlines()
        lines = [line.encode('utf-8') for line in lines]
        self.vim.current.buffer[:] = lines

    def build(self):
        response = self.get_json('/build', {}, 60)

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
        parameters = {}
        parameters['Type'] = mode
        response = self.get_json('/gettestcontext', parameters)
        return response['TestCommand']

    def codeFormat(self):
        parameters = {}
        parameters['ExpandTab'] = bool(int(self.vim.eval('&expandtab')))
        response = self.get_json('/codeformat', parameters)
        self.setBuffer(response["Buffer"])

    def fix_usings(self):
        js = self.get_json('/fixusings')
        self.setBuffer(js["Buffer"])
        return parse_quickfix_response(js, 'AmbiguousResults')

    def addReference(self):
        parameters = {}
        parameters["reference"] = self.vim.eval("a:ref")
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
        return self.get_navigate_response(js)

    def navigateDown(self):
        js = self.get_json('/navigatedown')
        return self.get_navigate_response(js)

    def get_navigate_response(self, response):
        if response is None:
            return {}
        else:
            return {'Line': response['Line'], 'Column': response['Column']}

def parse_quickfix_response(response, key=None):
    '''Parse the quickfix response'''
    if response is None:
        return []

    if key is not None:
        return parse_quickfix_response(response[key])

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
