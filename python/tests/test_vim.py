#!/usr/bin/env python
# -*- coding: utf-8 -*-

import mock
import tests.mock_vim as vim
from omnisharp import OmniSharp

def test_get_response_no_server():
    response = OmniSharp.getResponse("my_endpoint")
    expected_response = ''
    assert expected_response == response

@mock.patch('urllib2.build_opener')
def test_get_response_mocked_server(build_opener):
    mocked_response = '\xef\xbb\xbfMocked response with UTF-8 BOM'
    build_opener \
        .return_value.open \
        .return_value.read \
        .return_value = mocked_response
    response = OmniSharp.getResponse("my_endpoint")

    expected_response = mocked_response[3:]
    assert expected_response == response
