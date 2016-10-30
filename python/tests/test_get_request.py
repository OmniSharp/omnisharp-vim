#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''Initial set of tests for the OmniSharp Python logic'''

try:
    import unittest.mock as mock
except ImportError:
    import mock

import json

import omnisharp_impl

def mock_eval(expr):
    '''Mock vim.eval function.

    This will have hard-coded cases, which represent likely values returned by
    the actual vim implementation

    Args:
        expr (str): The expression that vim would evaluate
    '''
    if expr.startswith('line('):
        return "9"
    elif expr.startswith('col('):
        return "16"
    elif expr.startswith('getline('):
        return ["mybufferdata"]
    elif expr.startswith('g:OmniSharp_timeout'):
        return 123
    elif expr.startswith('g:OmniSharp'):
        return "some_global_setting"

def mock_vim():
    '''A helper methods for setting a Vim Mock'''
    vim = mock.MagicMock()
    vim.eval = mock.MagicMock(side_effect=mock_eval)
    vim.current.buffer.name = "/home/user/src/project/SomeFile.cs"
    vim.command = mock.MagicMock()

    return vim

@mock.patch('omnisharp_impl.OmniSharp._request')
def test_check_alive(mock_request):
    '''Test that the response is correctly interpreted as byte-strings'''
    vim = mock_vim()
    omnisharp = omnisharp_impl.OmniSharp(vim)

    for expected_value in ['true', 'false']:
        mock_request.return_value = expected_value.encode('utf-8')
        response = omnisharp.getResponse('/checkalivestatus')
        assert response == expected_value

@mock.patch('omnisharp_impl.OmniSharp._request')
def test_find_symbols(mock_request):
    '''Test how quickfix list is parsed.'''
    example_response = {
        "QuickFixes": [
            {
                "LogLevel": None,
                "FileName": "/home/user/src/my/project/File.cs",
                "Line": 160,
                "Column": 9,
                "EndLine": 0,
                "EndColumn": 0,
                "Text": "TestTimeToLive\t(in My.NameSpace)"
            }
        ]
    }

    vim = mock_vim()
    omnisharp = omnisharp_impl.OmniSharp(vim)

    mock_request.return_value = json.dumps(example_response).encode('utf-8')
    symbols = omnisharp.findSymbols()
    assert symbols == [
        {'filename': '/home/user/src/my/project/File.cs',
         'text': 'TestTimeToLive\t(in My.NameSpace)',
         'col': 9,
         'vcol': 0,
         'lnum': 160}]
