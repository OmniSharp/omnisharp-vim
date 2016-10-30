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

        proxy = request.ProxyHandler({})
        opener = request.build_opener(proxy)
        req = request.Request(target)
        req.add_header('Content-Type', 'application/json')

        try:
            response = opener.open(req, json.dumps(parameters).encode('utf-8'), timeout)
            self.vim.command("let g:serverSeenRunning = 1")
            res = response.read()
            if res.startswith(b"\xef\xbb\xbf"):  # Drop UTF-8 BOM
                res = res[3:]

            return res.decode('utf-8')
        except Exception as e:
            self.vim.command("let g:serverSeenRunning = 0")
            return ''

    def findUsages(self):
        parameters = {}
        parameters['MaxWidth'] = int(self.vim.eval('g:OmniSharp_quickFixLength'))
        js = self.getResponse('/findusages', parameters)
        return self.get_quickfix_list(js, 'QuickFixes')

    def findMembers(self):
        parameters = {}
        parameters['MaxWidth'] = int(self.vim.eval('g:OmniSharp_quickFixLength'))
        js = self.getResponse('/currentfilemembersasflat', parameters)
        return self.quickfixes_from_response(json.loads(js))

    def findImplementations(self):
        parameters = {}
        parameters['MaxWidth'] = int(self.vim.eval('g:OmniSharp_quickFixLength'))
        js = self.getResponse('/findimplementations', parameters)
        return self.get_quickfix_list(js, 'QuickFixes')

    def gotoDefinition(self):
        js = self.getResponse('/gotodefinition')
        if(js != ''):
            definition = json.loads(js)
            if(definition['FileName'] != None):
                self.openFile(definition['FileName'].replace("'","''"), definition['Line'], definition['Column'])
            else:
                print("Not found")

    def openFile(self, filename, line, column):
        self.vim.command("call OmniSharp#JumpToLocation('%(filename)s', %(line)s, %(column)s)" % locals())

    def getCodeActions(self, mode):
        parameters = self.codeActionParameters(mode)
        js = self.getResponse('/getcodeactions', parameters)
        if js != '':
            actions = json.loads(js)['CodeActions']
            return actions
        return []

    def runCodeAction(self, mode, action):
        parameters = self.codeActionParameters(mode)
        parameters['codeaction'] = action
        js = self.getResponse('/runcodeaction', parameters)
        text = json.loads(js)['Text']
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
        js = self.getResponse('/fixcodeissue')
        text = json.loads(js)['Text']
        self.setBufferText(text)

    def getCodeIssues(self):
        js = self.getResponse('/getcodeissues')
        return self.get_quickfix_list(js, 'QuickFixes')

    def codeCheck(self):
        js = self.getResponse('/codecheck')
        return self.get_quickfix_list(js, 'QuickFixes')

    def typeLookup(self, ret):
        parameters = {}
        parameters['includeDocumentation'] = self.vim.eval('a:includeDocumentation')
        js = self.getResponse('/typelookup', parameters)
        if js != '':
            response = json.loads(js)
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
        js = self.getResponse('/rename', parameters)
        return js

    def setBuffer(self, buffer):
        lines = buffer.splitlines()
        lines = [line.encode('utf-8') for line in lines]
        self.vim.current.buffer[:] = lines

    def build(self):
        js = json.loads(self.getResponse('/build', {}, 60))

        success = js["Success"]
        if success:
            print("Build succeeded")
        else:
            print("Build failed")

        return self.quickfixes_from_js(js, 'QuickFixes')

    def buildcommand(self):
        self.vim.command("let b:buildcommand = '%s'" % self.getResponse('/buildcommand'))

    def getTestCommand(self):
        mode = self.vim.eval('a:mode')
        parameters = {}
        parameters['Type'] = mode
        response = json.loads(self.getResponse('/gettestcontext', parameters))
        testCommand = "let s:testcommand = '%(TestCommand)s'" % response
        self.vim.command(testCommand)

    def codeFormat(self):
        parameters = {}
        parameters['ExpandTab'] = bool(int(self.vim.eval('&expandtab')))
        response = json.loads(self.getResponse('/codeformat', parameters))
        self.setBuffer(response["Buffer"])

    def fix_usings(self):
        response = self.getResponse('/fixusings')
        js = json.loads(response)
        self.setBuffer(js["Buffer"])
        return self.get_quickfix_list(response, 'AmbiguousResults')

    def addReference(self):
        parameters = {}
        parameters["reference"] = self.vim.eval("a:ref")
        js = self.getResponse("/addreference", parameters)
        if js != '':
            message = json.loads(js)['Message']
            print(message)

    def findSyntaxErrors(self):
        js = self.getResponse('/syntaxerrors')
        return self.get_quickfix_list(js, 'Errors')

    def findSemanticErrors(self):
        js = self.getResponse('/semanticerrors')
        return self.get_quickfix_list(js, 'Errors')

    def findTypes(self):
        js = self.getResponse('/findtypes')
        return self.get_quickfix_list(js, 'QuickFixes')

    def findSymbols(self):
        js = self.getResponse('/findsymbols')
        return self.get_quickfix_list(js, 'QuickFixes')

    def get_quickfix_list(self, js, key):
        if js != '':
            response = json.loads(js)
            return self.quickfixes_from_js(response, key)
        return []

    def quickfixes_from_js(self, js, key):
        if js[key] is not None:
            return self.quickfixes_from_response(js[key])
        return []

    def quickfixes_from_response(self, response):
        items = []
        for quickfix in response:
            if 'Text' in quickfix:
                text = quickfix['Text']
            #syntax errors returns 'Message' instead of 'Text'. I need to sort this out.
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

    def lookupAllUserTypes(self):
        js = self.getResponse('/lookupalltypes')
        if js != '':
            response = json.loads(js)
            if response != None:
                self.vim.command("let s:allUserTypes = '%s'" % (response['Types']))
                self.vim.command("let s:allUserInterfaces = '%s'" % (response['Interfaces']))

    def navigateUp(self):
        js = self.getResponse('/navigateup')
        return self.get_navigate_response(js)

    def navigateDown(self):
        js = self.getResponse('/navigatedown')
        return self.get_navigate_response(js)

    def get_navigate_response(self, js):
        if js != '':
            response = json.loads(js)
            return {'Line': response['Line'], 'Column': response['Column']}
        else:
            return {}
