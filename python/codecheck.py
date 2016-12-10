#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''A code check tool for NeoMake to use of OmniShrap.'''

import argparse
import json
import os
import sys
from urllib.parse import urljoin

import implementation

def make_request(host, endpoint, filename):
    '''Make a request to the server

    Args:
        host (str): The host for the server.

        endpoint (str): The endpoint to call on the host.

        filename (str): The filename that is in the solution loaded by the
            OmniSharp server running on the host.

    Returns:
        response (dict): Parsed JSON message.
    '''
    with open(filename, 'r') as cs_file:
        contents = cs_file.read()

    request = {
        'filename': filename,
        'buffer': contents
    }

    url = urljoin(host, endpoint)
    response = implementation.make_request(url, request, timeout=1)

    return json.loads(response)

def main():
    '''Main'''
    parser = argparse.ArgumentParser()
    parser.add_argument('hostname', help='OmniSharp server root address')
    parser.add_argument('filename', help='File to process')
    parser.add_argument('--code-check', action="store_true")
    parser.add_argument('--syntax-errors', action="store_true")
    parser.add_argument('--semantic-errors', action="store_true")
    parser.add_argument('--code-issues', action="store_true")

    def request(endpoint, key):
        '''A request wrapper.'''
        return make_request(args.hostname, endpoint, args.filename).get(key, [])

    args = parser.parse_args()

    if not os.path.exists(args.filename):
        raise RuntimeError("The specified file {} does not exist!".format(
            args.filename))

    args.filename = os.path.abspath(args.filename)

    results = []
    if args.code_check:
        results += request('/codecheck', 'QuickFixes')
    if args.syntax_errors:
        results += request('/syntaxerrors', 'Errors')
    if args.semantic_errors:
        results += request('/semanticerrors', 'Errors')
    if args.code_issues:
        results += request('/getcodeissues', 'QuickFixes')

    if len(results) > 0:
        print('\n'.join(_map(i) for i in results))
        sys.exit(1)

def _map(item):
    '''Map an item in the response to a string to be printed out.'''
    if 'Message' in item:
        item['Text'] = item['Message']
        item['LogLevel'] = 'Error'

    return '{FileName} ({Line} {Column}): {LogLevel} {Text}'.format(**item)

if __name__ == '__main__':
    main()
