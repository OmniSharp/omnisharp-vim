#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Bootstrap the python environment for use with vim

Sets up logging and imports commands into namespace

"""

import logging
import os
import os.path

import vim  # pylint: disable=import-error
from omnisharp.commands import *
from omnisharp.vimcmd import vimcmd

_log_file = ''


def _setup_logging():
    global _log_file
    logger = logging.getLogger('omnisharp')
    level = vim.eval('g:OmniSharp_loglevel').upper()
    logger.setLevel(getattr(logging, level))

    log_dir = os.path.realpath(os.path.join(
        vim.eval('g:OmniSharp_python_path'),
        '..',
        'log'))
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    _log_file = os.path.join(log_dir, 'python.log')
    hdlr = logging.FileHandler(_log_file)
    logger.addHandler(hdlr)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    hdlr.setFormatter(formatter)


_setup_logging()


@vimcmd
def getLogFile():
    return _log_file
