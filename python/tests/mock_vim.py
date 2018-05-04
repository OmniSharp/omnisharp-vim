#!/usr/bin/env python
# -*- coding: utf-8 -*-

import sys
import os
import mock

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
    elif expr.startswith('g:OmniSharp_translate_cygwin_wsl'):
        return 0
    elif expr.startswith('g:OmniSharp'):
        return "some_global_setting"
    elif expr == 'expand("<sfile>:p:h")':
        return os.path.dirname(__file__)

def mock_vim():
    '''A helper methods for setting a Vim Mock'''
    vim = mock.MagicMock()
    vim.eval = mock.MagicMock(side_effect=mock_eval)
    vim.current.buffer.name = "/home/user/src/project/SomeFile.cs"
    vim.command = mock.MagicMock()

    return vim

sys.modules['vim'] = mock_vim()
