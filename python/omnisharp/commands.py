#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging

import vim  # pylint: disable=import-error

from .util import BaseCtx
from .util import find_free_port as util_find_free_port
from .util import (formatPathForClient, formatPathForServer, getResponse,
                   quickfixes_from_response)
from .vimcmd import vimcmd

logger = logging.getLogger('omnisharp')


class VimUtilCtx(BaseCtx):
    """ Implementation of a UtilCtx that gets data from vim API """

    @property
    def buffer_name(self):
        return vim.current.buffer.name

    @property
    def translate_cygwin_wsl(self):
        return bool(int(vim.eval('g:OmniSharp_translate_cygwin_wsl'))),

    @property
    def cwd(self):
        return vim.eval('getcwd()')

    @property
    def timeout(self):
        return int(vim.eval('g:OmniSharp_timeout'))

    @property
    def host(self):
        return vim.eval('OmniSharp#GetHost()')

    @property
    def line(self):
        return vim.current.window.cursor[0]

    @property
    def column(self):
        return vim.current.window.cursor[1] + 1

    @property
    def buffer(self):
        return '\r\n'.join(vim.eval("getline(1,'$')")[:])


ctx = VimUtilCtx()


def openFile(filename, line=0, column=0, noautocmd=0):
    cmd = "call OmniSharp#JumpToLocation('{0}', {1}, {2}, {3})" \
          .format(filename, line, column, noautocmd)
    vim.command(cmd)


def setBuffer(text):
    if text is None:
        return False
    pos = vim.current.window.cursor
    lines = text.splitlines()
    lines = [line.encode('utf-8') for line in lines]
    vim.current.buffer[:] = lines
    vim.current.window.cursor = pos
    return True


@vimcmd
def findUsages():
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    response = getResponse(ctx, '/findusages', parameters, json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def findMembers():
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    response = getResponse(ctx, '/currentfilemembersasflat', parameters,
                           json=True)
    return quickfixes_from_response(ctx, response)


@vimcmd
def findImplementations():
    parameters = {}
    parameters['MaxWidth'] = int(vim.eval('g:OmniSharp_quickFixLength'))
    response = getResponse(ctx, '/findimplementations', parameters, json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def getCompletions(partialWord):
    parameters = {}
    parameters['wordToComplete'] = partialWord

    parameters['WantDocumentationForEveryCompletionResult'] = \
        bool(int(vim.eval('g:omnicomplete_fetch_full_documentation')))

    want_snippet = \
        bool(int(vim.eval('g:OmniSharp_want_snippet')))

    parameters['WantSnippet'] = want_snippet
    parameters['WantMethodHeader'] = want_snippet
    parameters['WantReturnType'] = want_snippet

    response = getResponse(ctx, '/autocomplete', parameters, json=True)

    vim_completions = []
    if response is not None:
        for completion in response:
            vim_completions.append({
                'snip': completion['Snippet'] or '',
                'word': (completion['MethodHeader']
                         or completion['CompletionText']),
                'menu': completion['ReturnType'] or completion['DisplayText'],
                'info': ((completion['Description'] or ' ')
                         .replace('\r\n', '\n')),
                'icase': 1,
                'dup': 1
            })
    return vim_completions


@vimcmd
def gotoDefinition():
    definition = getResponse(ctx, '/gotodefinition', json=True)
    if definition.get('FileName'):
        filename = formatPathForClient(ctx, definition['FileName'].replace("'", "''"))
        openFile(filename, definition['Line'], definition['Column'])
    else:
        print("Not found")


@vimcmd
def getCodeActions(mode, version='v1'):
    parameters = codeActionParameters(mode, version)
    if version == 'v1':
        endpoint = '/getcodeactions'
    elif version == 'v2':
        endpoint = '/v2/getcodeactions'
    response = getResponse(ctx, endpoint, parameters, json=True)
    return response['CodeActions']


@vimcmd
def runCodeAction(mode, action, version='v1'):
    parameters = codeActionParameters(mode, version)
    if version == 'v1':
        parameters['codeaction'] = action
        response = getResponse(ctx, '/runcodeaction', parameters, json=True)
        if 'Text' in response:
            setBuffer(response['Text'])
            return True
    elif version == 'v2':
        parameters['identifier'] = action
        response = getResponse(ctx, '/v2/runcodeaction', parameters, json=True)
        changes = response.get('Changes')
        if changes:
            bufname = vim.current.buffer.name
            pos = vim.current.window.cursor
            for changeDefinition in changes:
                filename = formatPathForClient(ctx,
                                               changeDefinition['FileName'])
                openFile(filename, noautocmd=1)
                if not setBuffer(changeDefinition.get('Buffer')):
                    for change in changeDefinition.get('Changes', []):
                        setBuffer(change.get('NewText'))
            openFile(bufname, pos[0], pos[1], 1)
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
                'Start': {'Line': start[1], 'Column': start[2]},
                'End': {'Line': end[1], 'Column': end[2]}
            }
    return parameters


@vimcmd
def fixCodeIssue():
    response = getResponse(ctx, '/fixcodeissue', json=True)
    setBuffer(response.get('Text'))


@vimcmd
def getCodeIssues():
    response = getResponse(ctx, '/getcodeissues', json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def codeCheck():
    response = getResponse(ctx, '/codecheck', json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def signatureHelp():
    return getResponse(ctx, '/signatureHelp', json=True)


@vimcmd
def typeLookup(include_documentation):
    parameters = {
        'includeDocumentation': bool(include_documentation),
    }
    response = getResponse(ctx, '/typelookup', parameters, json=True)
    return {
        'type': response.get('Type', '') or '',
        'doc': response.get('Documentation', '') or '',
    }


@vimcmd
def renameTo(name):
    parameters = {
        'renameto': name,
    }
    response = getResponse(ctx, '/rename', parameters, json=True)
    changes = response['Changes']
    for change in changes:
        change['FileName'] = formatPathForClient(ctx, change['FileName'])
    return changes


@vimcmd
def build():
    response = getResponse(ctx, '/build', {}, 60, json=True)
    return {
        'Success': bool(response['Success']),
        'QuickFixes': quickfixes_from_response(ctx, response['QuickFixes']),
    }


@vimcmd
def getBuildCommand():
    return getResponse(ctx, '/buildcommand')


@vimcmd
def getTestCommand(mode):
    parameters = {
        'Type': mode,
    }
    response = getResponse(ctx, '/gettestcontext', parameters, json=True)
    return response['TestCommand']


@vimcmd
def codeFormat():
    parameters = {}
    parameters['ExpandTab'] = bool(int(vim.eval('&expandtab')))
    response = getResponse(ctx, '/codeformat', parameters, json=True)
    setBuffer(response.get("Buffer"))


@vimcmd
def fix_usings():
    response = getResponse(ctx, '/fixusings', json=True)
    setBuffer(response.get("Buffer"))
    return quickfixes_from_response(ctx, response['AmbiguousResults'])


@vimcmd
def addReference(ref):
    parameters = {
        'reference': formatPathForServer(ctx, ref),
    }
    response = getResponse(ctx, "/addreference", parameters, json=True)
    return response['Message']


@vimcmd
def findSyntaxErrors():
    response = getResponse(ctx, '/syntaxerrors', json=True)
    return quickfixes_from_response(ctx, response['Errors'])


@vimcmd
def findSemanticErrors():
    response = getResponse(ctx, '/semanticerrors', json=True)
    return quickfixes_from_response(ctx, response['Errors'])


@vimcmd
def findTypes():
    response = getResponse(ctx, '/findtypes', json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def findSymbols(filter=''):
    parameters = {}
    parameters["filter"] = filter
    response = getResponse(ctx, '/findsymbols', parameters, json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def lookupAllUserTypes():
    response = getResponse(ctx, '/findsymbols', {'filter': ''}, json=True)
    qf = response.get('QuickFixes', [])
    slnTypes = []
    slnInterfaces = []
    slnAttributes = []
    for symbol in qf:
        if symbol['Kind'] == 'Class':
            slnTypes.append(symbol['Text'])
            if symbol['Text'].endswith('Attribute'):
                slnAttributes.append(symbol['Text'][:-9])
        elif symbol['Kind'] == 'Interface':
            slnInterfaces.append(symbol['Text'])
    return {
        'userTypes': ' '.join(slnTypes),
        'userInterfaces': ' '.join(slnInterfaces),
        'userAttributes': ' '.join(slnAttributes),
    }


@vimcmd
def lookupAllUserTypesLegacy():
    response = getResponse(ctx, '/lookupalltypes', json=True)
    return {
        'userTypes': response['Types'],
        'userInterfaces': response['Interfaces'],
        'userAttributes': '',
    }


@vimcmd
def navigateUp():
    get_navigate_response('/navigateup')


@vimcmd
def navigateDown():
    get_navigate_response('/navigatedown')


def get_navigate_response(endpoint):
    response = getResponse(ctx, endpoint, json=True)
    vim.current.window.cursor = (response['Line'], response['Column'] - 1)


@vimcmd
def find_free_port():
    return util_find_free_port()


@vimcmd
def checkAliveStatus():
    try:
        return getResponse(ctx, "/checkalivestatus", timeout=0.2) == 'true'
    except Exception:
        return 0


@vimcmd
def reloadSolution():
    getResponse(ctx, '/reloadsolution')


@vimcmd
def updateBuffer():
    getResponse(ctx, "/updatebuffer")


@vimcmd
def addToProject():
    getResponse(ctx, "/addtoproject")


__all__ = [name for name, fxn in locals().items()
           if getattr(fxn, 'is_cmd', False)]
