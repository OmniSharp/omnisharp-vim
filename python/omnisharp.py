#!/usr/bin/env python2
# -*- coding: utf-8 -*-

from __future__ import print_function

import logging
import os
import vim
import implementation

__all__ = ('omnisharp', 'logger')

def _config_logging(logger_):
    '''An internal function used in order not to pollute the namespace.

    Args:
        logger_ (logging.Logger): The logger to setup.

    '''
    logger_.setLevel(logging.WARNING)

    log_dir = os.path.join(vim.eval('expand("<sfile>:p:h")'), '..', 'log')
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    hdlr = logging.FileHandler(os.path.join(log_dir, 'python.log'))
    logger_.addHandler(hdlr)

    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    hdlr.setFormatter(formatter)

# Singleton for use in the plugin
omnisharp = implementation.OmniSharp(vim)

logger = logging.getLogger('omnisharp')
_config_logging(logger)
