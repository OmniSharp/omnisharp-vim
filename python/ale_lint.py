#!/usr/bin/env python
# -*- coding: utf-8 -*-
from __future__ import print_function

import argparse
import logging
import os
import sys
from os.path import join, pardir, realpath

from omnisharp.util import UtilCtx, getResponse, quickfixes_from_response


def _setup_logging(level):
    logger = logging.getLogger('omnisharp')
    logger.setLevel(level)

    log_dir = realpath(join(__file__, pardir, pardir, 'log'))
    if not os.path.exists(log_dir):
        os.makedirs(log_dir)
    log_file = os.path.join(log_dir, 'lint.log')
    hdlr = logging.FileHandler(log_file)
    logger.addHandler(hdlr)
    formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
    hdlr.setFormatter(formatter)
    return logger


def main():
    """ Run a /codecheck on a file """

    log_levels = {
        'debug': logging.DEBUG,
        'info': logging.INFO,
        'warning': logging.WARNING,
        'error': logging.ERROR,
        'critical': logging.CRITICAL,
    }

    parser = argparse.ArgumentParser(description=main.__doc__)
    parser.add_argument('--host', required=True,
                        help="Host and port of omnisharp server")
    parser.add_argument('--filename', required=True,
                        help="Path of the file being checked")
    parser.add_argument('--cwd', help="Current working directory of vim",
                        default='')
    parser.add_argument('--delimiter', default=':',
                        help="Delimiter for output (default %(default)s)")
    parser.add_argument('--level', help="Log level (default %(default)s)",
                        choices=log_levels.keys(), default='info')
    parser.add_argument('--translate', action='store_true',
                        help="If provided, translate cygwin/wsl paths")
    parser.add_argument('--encoding', required=True,
                        help="Encoding for output")
    args = parser.parse_args()
    logger = _setup_logging(log_levels[args.level])
    try:
        do_codecheck(logger, args.filename.strip(), args.host, args.cwd,
                     args.translate, args.delimiter, args.encoding)
    except Exception as e:
        logger.exception("Error doing codecheck")


def do_codecheck(logger, filename, host, cwd, translate, delimiter, encoding):
    ctx = UtilCtx(
        buffer_name=filename,
        translate_cygwin_wsl=translate,
        cwd=cwd,
        timeout=4,
        host=host,
        buffer=''.join(sys.stdin),
    )

    response = getResponse(ctx, '/codecheck', json=True)
    quickfixes = quickfixes_from_response(ctx, response['QuickFixes'])

    keys = ['filename', 'lnum', 'col', 'type', 'subtype', 'text']
    for item in quickfixes:
        s = delimiter.join([str(item.get(k, '')) for k in keys]) + '\n'
        if sys.version_info.major == 3:
            sys.stdout.buffer.write(s.encode(encoding))
        elif sys.version_info.major == 2:
            sys.stdout.write(unicode(s).encode(encoding))


if __name__ == '__main__':
    main()
