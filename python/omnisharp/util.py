# -*- coding: utf-8 -*-
""" Utilities """

import json as jsonlib
import logging
import os.path
import platform
import re
import socket
import sys
from contextlib import closing

from .exceptions import BadResponseError, ServerConnectionError

try:
    from urllib import parse as urlparse
    from urllib import request
except ImportError:
    import urllib2 as request
    import urlparse


logger = logging.getLogger('omnisharp.util')


class BaseCtx(object):
    """
    Provides properties that will be shared by all implementations of UtilCtx
    """

    def __init__(self):
        self.is_msys = 'msys_nt' in platform.system().lower()
        self.is_cygwin = 'cygwin' in platform.system().lower()
        self.is_wsl = ('linux' in platform.system().lower()
                       and 'microsoft' in platform.release().lower())


class UtilCtx(BaseCtx):
    """
    Simple class that holds data that is needed by util functions

    Most of the util methods require this object (or an equivalent replacement)
    when they are called. The indirection here is to make two things easier:
    testing, and running outside of a vim context.

    Tests become easier because instead of mocking vim API functions, you can
    just pass in an object with whatever test data you wish. As a bonus, as
    long as the interface to the UtilCtx doesn't change, you can refactor the
    vim implementation all you like without breaking tests.

    Running outside a vim context is easier too, for the same reason as tests.
    This is useful for such purposes as an ALE linter script.

    """

    def __init__(
            self,
            buffer_name='',
            translate_cygwin_wsl=False,
            cwd='',
            timeout=1,
            host='',
            line=1,
            column=1,
            buffer='',
    ):
        super(UtilCtx, self).__init__()
        self.buffer_name = buffer_name
        self.translate_cygwin_wsl = translate_cygwin_wsl
        self.cwd = cwd
        self.timeout = timeout
        self.host = host
        self.line = line
        self.column = column
        self.buffer = buffer


class VimUtilCtx(BaseCtx):
    """ Implementation of a UtilCtx that gets data from vim API """
    def __init__(self, vim):
        super(VimUtilCtx, self).__init__()
        self._vim = vim

    @property
    def buffer_name(self):
        # We can't use self._vim.current.buffer.name because it returns the real
        # path. expand('%') will preserve the symlinked path, if one exists.
        return self._vim.eval("expand('%:p')")

    @property
    def translate_cygwin_wsl(self):
        return bool(int(self._vim.eval('g:OmniSharp_translate_cygwin_wsl')))

    @property
    def cwd(self):
        return self._vim.eval('getcwd()')

    @property
    def timeout(self):
        return int(self._vim.eval('g:OmniSharp_timeout'))

    @property
    def host(self):
        return self._vim.eval('OmniSharp#GetHost()')

    @property
    def line(self):
        return self._vim.current.window.cursor[0]

    @property
    def column(self):
        return self._vim.current.window.cursor[1] + 1

    @property
    def buffer(self):
        return '\r\n'.join(self._vim.eval("getline(1,'$')")[:])


def quickfixes_from_response(ctx, response):
    items = []
    for quickfix in response:
        # syntax errors returns 'Message' instead of 'Text'.
        # I need to sort this out.
        text = quickfix.get('Text') or quickfix.get('Message', '')

        filename = quickfix.get('FileName')
        if filename is None:
            filename = ctx.buffer_name
        else:
            filename = formatPathForClient(ctx, filename)

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


# When working in Windows Subsystem for Linux (WSL) or Cygwin, vim uses
# unix-style paths but OmniSharp (with a Windows binary) uses Windows
# paths. This means that filenames returned FROM OmniSharp must be
# translated from e.g. "C:\path\to\file" to "/mnt/c/path/to/file", and
# filenames sent TO OmniSharp must be translated in the other direction.
def formatPathForServer(ctx, filepath):
    if ctx.translate_cygwin_wsl and (ctx.is_msys or ctx.is_cygwin or ctx.is_wsl):
        if ctx.is_msys:
            pattern = r'^/([a-zA-Z])/'
        elif ctx.is_cygwin:
            pattern = r'^/cygdrive/([a-zA-Z])/'
        else:
            pattern = r'^/mnt/([a-zA-Z])/'
        return re.sub(pattern, r'\1:\\', filepath).replace('/', '\\')
    return filepath


def formatPathForClient(ctx, filepath):
    if ctx.translate_cygwin_wsl and (ctx.is_msys or ctx.is_cygwin or ctx.is_wsl):
        def path_replace(matchobj):
            if ctx.is_msys:
                prefix = '/{0}/'
            elif ctx.is_cygwin:
                prefix = '/cygdrive/{0}/'
            else:
                prefix = '/mnt/{0}/'
            return prefix.format(matchobj.group(1).lower())
        return re.sub(r'^([a-zA-Z]):\\', path_replace, filepath).replace('\\', '/')
    # Shorten path names by checking if we can make them relative
    cwd = ctx.cwd
    if cwd and os.path.commonprefix([cwd, filepath]) == cwd:
        filepath = filepath[len(cwd):].lstrip('/\\')
    return filepath


def getResponse(ctx, path, additional_parameters=None, timeout=None, json=False):
    parameters = {}
    parameters['line'] = ctx.line
    parameters['column'] = ctx.column
    parameters['buffer'] = ctx.buffer
    parameters['filename'] = formatPathForServer(ctx, ctx.buffer_name)
    if additional_parameters is not None:
        parameters.update(additional_parameters)

    if timeout is None:
        timeout = ctx.timeout

    return doRequest(ctx.host, path, parameters, timeout=timeout,
                     json=json)


def doRequest(host, path, parameters, timeout=1, json=False):
    target = urlparse.urljoin(host, path)

    proxy = request.ProxyHandler({})
    opener = request.build_opener(proxy)
    req = request.Request(target)
    req.add_header('Content-Type', 'application/json')
    body = jsonlib.dumps(parameters)

    if sys.version_info >= (3, 0):
        body = body.encode('utf-8')

    logger.info("Request: %s", target)
    logger.debug(body)

    try:
        response = opener.open(req, body, timeout)
        res = response.read()
    except Exception as e:
        logger.exception("Could not connect to OmniSharp server: %s", target)
        raise ServerConnectionError(str(e))

    if sys.version_info >= (3, 0):
        res = res.decode('utf-8')
    if res.startswith("\xef\xbb\xbf"):  # Drop UTF-8 BOM
        res = res[3:]

    logger.info("Received Response: %s", target)
    logger.debug(res)
    if json:
        try:
            return jsonlib.loads(res)
        except Exception as e:
            logger.error("Error parsing response as json: \n%s", res)
            raise BadResponseError(str(e))
    return res


def find_free_port():
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    with closing(sock):
        sock.bind(('', 0))
        return sock.getsockname()[1]
