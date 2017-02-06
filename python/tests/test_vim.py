#!/usr/bin/env python
# -*- coding: utf-8 -*-

import mock
import sys
import tests.mock_vim as vim
from omnisharp import OmniSharp

def test_get_response_no_server():
    response = OmniSharp.getResponse("http://my_endpoint")
    expected_response = ''
    assert expected_response == response

if sys.version_info >= (3, 0):
    BUILD_OPENER = 'urllib.request.build_opener'
elif sys.version_info < (3, 0) and sys.version_info >= (2, 5):
    BUILD_OPENER = 'urllib2.build_opener'
else:
    raise ImportError("Unsupported python version")

@mock.patch(BUILD_OPENER)
def test_get_response_mocked_server(build_opener):
    mocked_response = '\xef\xbb\xbfMocked response with UTF-8 BOM'
    build_opener \
        .return_value.open \
        .return_value.read \
        .return_value = mocked_response
    response = OmniSharp.getResponse("http://my_endpoint")

    expected_response = mocked_response[3:]
    assert expected_response == response
