#!/usr/bin/env python
# -*- coding: utf-8 -*-

'''Tests for the util.py module'''

import sys

import pytest
from omnisharp.exceptions import BadResponseError, ServerConnectionError
from omnisharp.util import (UtilCtx, find_free_port, formatPathForClient,
                            formatPathForServer, getResponse,
                            quickfixes_from_response)


@pytest.fixture(scope='module')
def ctx():
    return UtilCtx()


def test_get_response_no_server(ctx):
    '''Test that the getResponse throws when there is no server'''
    port = find_free_port()
    with pytest.raises(ServerConnectionError):
        getResponse(ctx, "http://localhost:%d" % port)


def test_get_response_mocked_server(ctx, mocker):
    '''Test that we can get a response the server'''
    build_opener = mocker.patch('omnisharp.util.request.build_opener')
    expected_response = 'Mocked response with UTF-8 BOM'
    if sys.version_info >= (3, 0):
        mocked_response = (
            '\xef\xbb\xbf' + expected_response).encode('utf-8')
    else:
        mocked_response = '\xef\xbb\xbf' + expected_response

    build_opener \
        .return_value.open \
        .return_value.read \
        .return_value = mocked_response

    response = getResponse(ctx, "http://my_endpoint")

    assert expected_response == response


def test_get_json_response_mocked_server(ctx, mocker):
    '''Test that we can get a response the server'''
    build_opener = mocker.patch('omnisharp.util.request.build_opener')
    expected_response = '{"foo": "bar"}'
    if sys.version_info >= (3, 0):
        mocked_response = (
            '\xef\xbb\xbf' + expected_response).encode('utf-8')
    else:
        mocked_response = '\xef\xbb\xbf' + expected_response

    build_opener \
        .return_value.open \
        .return_value.read \
        .return_value = mocked_response

    response = getResponse(ctx, "http://my_endpoint", json=True)

    assert {'foo': 'bar'} == response


def test_get_bad_json_response(ctx, mocker):
    '''Malformed json response throws BadResponseError'''
    build_opener = mocker.patch('omnisharp.util.request.build_opener')
    expected_response = '{"foo": "bar"'
    if sys.version_info >= (3, 0):
        mocked_response = (
            '\xef\xbb\xbf' + expected_response).encode('utf-8')
    else:
        mocked_response = '\xef\xbb\xbf' + expected_response

    build_opener \
        .return_value.open \
        .return_value.read \
        .return_value = mocked_response

    with pytest.raises(BadResponseError):
        getResponse(ctx, "http://my_endpoint", json=True)


def test_format_no_translate(ctx):
    ctx.translate_cygwin_wsl = False

    path = '/foo/bar/baz'
    assert formatPathForClient(ctx, path) == path

    path = '/foo/bar/baz'
    assert formatPathForServer(ctx, path) == path


def test_format_client_relative(ctx):
    ctx.translate_cygwin_wsl = False
    ctx.cwd = '/foo'

    path = '/foo/bar/baz'
    assert formatPathForClient(ctx, path) == 'bar/baz'


def test_translate_for_server(ctx):
    ctx.translate_cygwin_wsl = True
    ctx.is_msys = True

    path = '/c/foo/bar'
    assert formatPathForServer(ctx, path) == r'c:\foo\bar'

    ctx.is_msys = False
    ctx.is_cygwin = True
    path = '/cygdrive/c/foo/bar'
    assert formatPathForServer(ctx, path) == r'c:\foo\bar'

    ctx.is_cygwin = False
    ctx.is_wsl = True
    path = '/mnt/c/foo/bar'
    assert formatPathForServer(ctx, path) == r'c:\foo\bar'


def test_translate_for_client(ctx):
    ctx.translate_cygwin_wsl = True
    ctx.is_msys = True

    path = r'C:\foo\bar'
    assert formatPathForClient(ctx, path) == '/c/foo/bar'

    ctx.is_msys = False
    ctx.is_cygwin = True
    assert formatPathForClient(ctx, path) == '/cygdrive/c/foo/bar'

    ctx.is_cygwin = False
    ctx.is_wsl = True
    assert formatPathForClient(ctx, path) == '/mnt/c/foo/bar'


def test_quickfixes_from_response(ctx):
    ctx.translate_cygwin_wsl = False

    response = [
        {
            'FileName': 'foo.cs',
            'Text': 'some text',
            'Line': 5,
            'Column': 8,
        },
    ]
    qf = quickfixes_from_response(ctx, response)
    expected = [
        {
            'filename': 'foo.cs',
            'text': 'some text',
            'lnum': 5,
            'col': 8,
            'vcol': 0,
        },
    ]
    assert qf == expected

    ctx.buffer_name = 'myfile.cs'
    response = [
        {
            'Message': 'some text',
            'Line': 5,
            'Column': 8,
            'LogLevel': 'Error',
        },
    ]
    qf = quickfixes_from_response(ctx, response)
    expected = [
        {
            'filename': ctx.buffer_name,
            'text': 'some text',
            'lnum': 5,
            'col': 8,
            'vcol': 0,
            'type': 'E',
        },
    ]
    assert qf == expected

    response = [
        {
            'FileName': 'foo.cs',
            'Text': 'some text',
            'Line': 5,
            'Column': 8,
            'LogLevel': 'Hidden',
        },
    ]
    qf = quickfixes_from_response(ctx, response)
    expected = [
        {
            'filename': 'foo.cs',
            'text': 'some text',
            'lnum': 5,
            'col': 8,
            'vcol': 0,
            'type': 'W',
            'subtype': 'Style',
        },
    ]
    assert qf == expected
