#!/usr/bin/env python
# -*- coding: utf-8 -*-

import logging

import vim  # pylint: disable=import-error

from .util import VimUtilCtx
from .util import find_free_port as util_find_free_port
from .util import (formatPathForClient, formatPathForServer, getResponse,
                   quickfixes_from_response, doRequest)
from .vimcmd import vimcmd

logger = logging.getLogger('omnisharp')


ctx = VimUtilCtx(vim)


def openFile(filename, line=0, column=0, editcommand='edit'):
    vim.command("let l:loc = {{ 'filename': '{0}', 'lnum': {1}, 'col': {2} }}"
                .format(filename, line, column))
    vim.command("call OmniSharp#locations#Navigate(l:loc, {0})".format(editcommand))


def setBuffer(text):
    if text is None:
        return False
    pos = vim.current.window.cursor
    lines = text.splitlines()
    lines = [line.encode('utf-8') for line in lines]
    vim.current.buffer[:] = lines
    try:
        vim.current.window.cursor = pos
    except vim.error:
        vim.current.window.cursor = (len(vim.current.buffer), pos[1])
    return True


@vimcmd
def findUsages():
    response = getResponse(ctx, '/findusages', json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def findMembers():
    response = getResponse(ctx, '/currentfilemembersasflat', json=True)
    return quickfixes_from_response(ctx, response)


@vimcmd
def findImplementations():
    response = getResponse(ctx, '/findimplementations', json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def getCompletions(partialWord):
    parameters = {}
    parameters['WordToComplete'] = partialWord

    parameters['WantDocumentationForEveryCompletionResult'] = \
        bool(int(vim.eval('g:omnicomplete_fetch_full_documentation')))

    want_snippet = \
        bool(int(vim.eval('g:OmniSharp_want_snippet')))

    without_overloads = \
        bool(int(vim.eval('g:OmniSharp_completion_without_overloads')))

    parameters['WantSnippet'] = want_snippet
    parameters['WantMethodHeader'] = True
    parameters['WantReturnType'] = True

    response = getResponse(ctx, '/autocomplete', parameters, json=True)

    vim_completions = []
    if response is not None:
        for cmp in response:
            if want_snippet:
                word = cmp['MethodHeader'] or cmp['CompletionText']
                menu = cmp['ReturnType'] or cmp['DisplayText']
            elif without_overloads:
                word = cmp['CompletionText']
                menu = ''
            else:
                word = cmp['CompletionText'] or cmp['MethodHeader']
                menu = cmp['DisplayText'] or cmp['MethodHeader']
                menu = ' '.join(filter(None, [cmp['ReturnType'], menu]))

            vim_completions.append({
                'snip': cmp['Snippet'] or '',
                'word': word,
                'menu': menu,
                'info': ((cmp['Description'] or ' ')
                         .replace('\r\n', '\n')),
                'icase': 1,
                'dup': 0 if without_overloads else 1
            })
    return vim_completions


@vimcmd
def gotoDefinition():
    definition = getResponse(ctx, '/gotodefinition', json=True)
    if definition.get('FileName'):
        return quickfixes_from_response(ctx, [definition])[0]
    else:
        return None


@vimcmd
def getCodeActions(mode):
    parameters = codeActionParameters(mode)
    response = getResponse(ctx, '/v2/getcodeactions', parameters, json=True)
    return response['CodeActions']


@vimcmd
def runCodeAction(mode, action):
    parameters = codeActionParameters(mode)
    parameters['identifier'] = action
    response = getResponse(ctx, '/v2/runcodeaction', parameters, json=True)
    changes = response.get('Changes')
    if changes:
        bufname = vim.current.buffer.name
        bufnum = vim.current.buffer.number
        pos = vim.current.window.cursor
        vim.command('let l:hidden_bak = &hidden | set hidden')
        for changeDefinition in changes:
            filename = formatPathForClient(ctx, changeDefinition['FileName'])
            openFile(filename, editcommand='silent')
            if not setBuffer(changeDefinition.get('Buffer')):
                for change in changeDefinition.get('Changes', []):
                    setBuffer(change.get('NewText'))
            if vim.current.buffer.number != bufnum:
                vim.command('silent write | silent edit')
        openFile(bufname, pos[0], pos[1], 'silent')
        vim.command('let &hidden = l:hidden_bak | unlet l:hidden_bak')
        return True
    return False


def codeActionParameters(mode):
    parameters = {}
    if mode == 'visual':
        start = vim.eval('getpos("\'<")')
        end = vim.eval('getpos("\'>")')
        # In visual line mode, getpos("'>")[2] is a large number (2147483647).
        # In python this is represented as a string, so when the length of this
        # string is greater than 5 it means the position is greater than 99999.
        # In this case, use the length of the line as the column position.
        if len(end[2]) > 5:
            end[2] = vim.eval('len(getline(%s))' % end[1])
        logger.error(end)
        parameters['Selection'] = {
            'Start': {'Line': start[1], 'Column': start[2]},
            'End': {'Line': end[1], 'Column': end[2]}
        }
    return parameters


@vimcmd
def codeCheck():
    response = getResponse(ctx, '/codecheck', json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])

@vimcmd
def globalCodeCheck():
    parameters = {}
    response = doRequest(ctx.host, '/codecheck', parameters, json=True)
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
        'Type': response.get('Type', '') or '',
        'Documentation': response.get('Documentation', '') or ''
    }


@vimcmd
def renameTo(name):
    parameters = {
        'renameto': name,
    }
    response = getResponse(ctx, '/rename', parameters, json=True)
    changes = response['Changes']
    ret = []
    for change in changes:
        ret.append({
            'FileName': formatPathForClient(ctx, change['FileName']),
            'Buffer': change['Buffer']
        })
    return ret


@vimcmd
def codeFormat():
    parameters = {}
    parameters['ExpandTab'] = bool(int(vim.eval('&expandtab')))
    response = getResponse(ctx, '/codeformat', parameters, json=True)
    setBuffer(response.get("Buffer"))


@vimcmd
def fixUsings():
    response = getResponse(ctx, '/fixusings', json=True)
    setBuffer(response.get("Buffer"))
    return quickfixes_from_response(ctx, response['AmbiguousResults'])


@vimcmd
def findSymbols(filter='', symbolfilter=''):
    parameters = {}
    parameters["filter"] = filter
    parameters["symbolfilter"] = symbolfilter
    response = getResponse(ctx, '/findsymbols', parameters, json=True)
    return quickfixes_from_response(ctx, response['QuickFixes'])


@vimcmd
def findHighlightTypes():
    # Original buffer lines
    bufferLines = ctx.buffer.split('\r\n')
    response = getResponse(ctx, '/highlight', json=True)
    highlights = response.get('Highlights', [])

    identifierKinds = ['constant name', 'enum member name', 'field name',
                       'identifier', 'local name', 'parameter name',
                       'property name', 'static symbol']
    interfaceKinds = ['interface name']
    methodKinds = ['extension method name', 'method name']
    typeKinds = ['class name', 'enum name', 'namespace name', 'struct name']

    types = []
    for hi in highlights:
        lnum = hi['StartLine'] - 1
        if lnum >= len(bufferLines):
            # An error has occurred with invalid line endings - perhaps a
            # combination of unix and dos line endings?
            return {'error': 'Invalid buffer - check line endings'}
        line = bufferLines[lnum]
        types.append({
            'kind': hi['Kind'],
            'name': line[hi['StartColumn'] - 1:hi['EndColumn'] - 1]
        })

    return {
        'identifiers': [t['name'] for t in types if t['kind'] in identifierKinds],
        'interfaces': [t['name'] for t in types if t['kind'] in interfaceKinds],
        'methods': [t['name'] for t in types if t['kind'] in methodKinds],
        'types': [t['name'] for t in types if t['kind'] in typeKinds]
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
def updateBuffer():
    getResponse(ctx, "/updatebuffer")


__all__ = [name for name, fxn in locals().items()
           if getattr(fxn, 'is_cmd', False)]
