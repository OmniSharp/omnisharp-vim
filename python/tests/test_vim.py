#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''Simple tests'''

import sys
import json
import mock

import tests.mock_vim as vim  # pylint: disable=unused-import
from omnisharp import OmniSharp

if sys.version_info >= (3, 0):
    BUILD_OPENER = 'urllib.request.build_opener'
elif sys.version_info < (3, 0) and sys.version_info >= (2, 5):
    BUILD_OPENER = 'urllib2.build_opener'
else:
    raise ImportError("Unsupported python version")


def test_get_response_no_server():
    '''Test that the response is empty when there is no server'''
    response = OmniSharp.getResponse("http://my_endpoint")
    expected_response = ''
    assert expected_response == response

@mock.patch(BUILD_OPENER)
def test_get_response_mocked_server(build_opener):
    '''Test that we can get a response the server'''
    expected_response = 'Mocked response with UTF-8 BOM'
    if sys.version_info >= (3, 0):
        mocked_response = (
            '\xef\xbb\xbf' + expected_response).encode('utf-8')
    elif sys.version_info < (3, 0) and sys.version_info >= (2, 5):
        mocked_response = '\xef\xbb\xbf' + expected_response

    build_opener \
        .return_value.open \
        .return_value.read \
        .return_value = mocked_response

    response = OmniSharp.getResponse("http://my_endpoint")

    assert expected_response == response

@mock.patch(BUILD_OPENER)
def test_get_json_response_mocked_server(build_opener):
    '''Test that we can get a response the server'''
    expected_response = '{"foo": "bar"}'
    if sys.version_info >= (3, 0):
        mocked_response = (
            '\xef\xbb\xbf' + expected_response).encode('utf-8')
    elif sys.version_info < (3, 0) and sys.version_info >= (2, 5):
        mocked_response = '\xef\xbb\xbf' + expected_response

    build_opener \
        .return_value.open \
        .return_value.read \
        .return_value = mocked_response

    response = OmniSharp.getResponse("http://my_endpoint")

    assert expected_response == response
    assert {'foo': 'bar'} == json.loads(response)
