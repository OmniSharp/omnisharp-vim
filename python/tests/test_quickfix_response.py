#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''Initial set of tests for the OmniSharp Python logic'''

import pytest

import omnisharp_impl

TESTDATA_NEGATIVE = [
    (None, None, []),
    ("", None, []),
    (2, None, []),
    (None, 'abc', []),
    ("", 'abc', []),
    ([{}], 'abc', []),
    ({}, 'abc', []),
]

@pytest.mark.parametrize('response, key, expected', TESTDATA_NEGATIVE)
def test_parse_quickfix_response_incorrect_response(response, key, expected):
    '''Negative testing of the parse_quickfix_response function.'''
    assert omnisharp_impl.parse_quickfix_response(response, key) == expected, \
        "Failed to handle a None value"

EXAMPLE_QUICKFIX_RESPONSE = {
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
    ],
    "Errors": [
        {
            "LogLevel": None,
            "FileName": "/home/user/src/my/project/File.cs",
            "Line": 160,
            "Column": 9,
            "EndLine": 0,
            "EndColumn": 0,
            "Message": "TestTimeToLive\t(in My.NameSpace)"
        }
    ]
}

TESTDATA_INCORRECT_KEY = [
    (EXAMPLE_QUICKFIX_RESPONSE, None, []),
    (EXAMPLE_QUICKFIX_RESPONSE, 'abc', []),
]
@pytest.mark.parametrize('response, key, expected', TESTDATA_INCORRECT_KEY)
def test_parse_quickfix_response_incorrect_key(response, key, expected):
    assert omnisharp_impl.parse_quickfix_response(response, None) == expected, \
        "Failed to handle a valid response and invalid key"

def test_parse_quickfix_response():
    '''Test how quickfix list is parsed.'''
    assert omnisharp_impl.parse_quickfix_response(EXAMPLE_QUICKFIX_RESPONSE, 'QuickFixes') == [
        {
            'filename': EXAMPLE_QUICKFIX_RESPONSE['QuickFixes'][0]['FileName'],
            'text': EXAMPLE_QUICKFIX_RESPONSE['QuickFixes'][0]['Text'],
            'lnum': EXAMPLE_QUICKFIX_RESPONSE['QuickFixes'][0]['Line'],
            'col': EXAMPLE_QUICKFIX_RESPONSE['QuickFixes'][0]['Column'],
            'vcol': 0
        }
    ], \
        "Failed to handle a correct case"

    assert omnisharp_impl.parse_quickfix_response(EXAMPLE_QUICKFIX_RESPONSE, 'Errors') == [
        {
            'filename': EXAMPLE_QUICKFIX_RESPONSE['Errors'][0]['FileName'],
            'text': EXAMPLE_QUICKFIX_RESPONSE['Errors'][0]['Message'],
            'lnum': EXAMPLE_QUICKFIX_RESPONSE['Errors'][0]['Line'],
            'col': EXAMPLE_QUICKFIX_RESPONSE['Errors'][0]['Column'],
            'vcol': 0
        }
    ], \
        "Failed to handle a correct case"
