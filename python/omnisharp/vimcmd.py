# -*- coding: utf-8 -*-
"""
Provides vimcmd, a wrapper for python functions that will be called from vim
"""

import functools
import json
import logging

try:
    import vim  # pylint: disable=import-error
    _has_vim = True
except ImportError:
    _has_vim = False

logger = logging.getLogger('omnisharp')


def vimcmd(fxn):
    """ Decorator for functions that will be run from vim """

    @functools.wraps(fxn)
    def wrapper(*args, **kwargs):
        try:
            ret = fxn(*args, **kwargs)
        except Exception as e:
            logger.exception("Error running python %s()", fxn.__name__)
            _set_return_error(e)
            return 0
        else:
            _set_return_error(None)
            return ret
    wrapper.is_cmd = True
    return wrapper


def _set_return_error(err):
    # If we're not in a vim plugin, don't try to set the error
    if not _has_vim:
        return

    # Exceptions don't really work across the vim-python boundary, so instead
    # we catch the exception and set it into a global variable. The calling vim
    # code will then manually check that value after the command completes.
    if err is None:
        vim.command('let g:OmniSharp_py_err = {}')
    else:
        err_dict = {
            "code": getattr(err, 'code', 'ERROR'),
            "msg": str(err),
        }
        # Not the best way to serialize to vim types,
        # but it'll work for this specific case
        vim.command("let g:OmniSharp_py_err = %s" % json.dumps(err_dict))
