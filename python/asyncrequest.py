#!/usr/bin/env python
# -*- coding: utf-8 -*-

import vim
import json
import cgi
import types
import threading

import urllib

import sys
if sys.version_info >= (3, 0):
    from urllib.parse import urljoin
    from urllib import request
elif sys.version_info < (3, 0) and sys.version_info >= (2, 5):
    import urllib2 as request
    from urlparse import urljoin
else:
    raise ImportError("Unsupported python version: {}".format(sys.version_info))


class ThreadUrl(threading.Thread):

    def __init__(self, url, callback, data, timeout):
        threading.Thread.__init__(self)
        self.url = url
        self.data = data
        self.timeout = timeout
        self.callback = callback

    def run(self):
        try:
            proxy = request.ProxyHandler({})
            opener = request.build_opener(proxy)
            response = opener.open(self.url, self.data, self.timeout)
            self.callback(response.read())
        except:
            self.callback(None)

def urlopen_async(url, callback, data, timeout):
    thread = ThreadUrl(url, callback, data, timeout)
    thread.start()

def get_response_async(endPoint, callback, params=None, timeout=None):
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

    target = urljoin(host, endPoint)
    data = urllib.urlencode(parameters).encode('utf-8')

    def urlopen_callback(data):
        #print(data)
        if data is None:
            vim.command("let g:serverSeenRunning = 0")
            callback(None)
        else:
            vim.command("let g:serverSeenRunning = 1")
            #jsonStr = data.decode('utf-8')
            jsonObj = json.loads(data)
            callback(jsonObj)

    urlopen_async(
        target,
        urlopen_callback,
        data,
        timeout)
