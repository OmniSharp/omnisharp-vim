""" OmniSharp source for deoplete """
import logging
import os
import sys
from os.path import abspath, dirname, exists, join, pardir

from .base import Base

OMNISHARP_ROOT = abspath(join(dirname(__file__), pardir, pardir, pardir,
                              pardir))
sys.path.append(join(OMNISHARP_ROOT, 'python'))


try:
    from omnisharp.util import getResponse, VimUtilCtx
except ImportError:
    pass


class Source(Base):
    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'omnisharp'
        self.mark = '[OS]'
        self.rank = 500
        self.is_volatile = True
        self.filetypes = ['cs']
        self._ctx = None
        self._setup_logging()
        self._log = logging.getLogger('omnisharp.deoplete')

    def _setup_logging(self):
        logger = logging.getLogger('omnisharp')
        level = self.vim.eval('g:OmniSharp_loglevel').upper()
        logger.setLevel(getattr(logging, level))

        log_dir = join(OMNISHARP_ROOT, 'log')
        if not exists(log_dir):
            os.makedirs(log_dir)
        log_file = join(log_dir, 'deoplete.log')
        hdlr = logging.FileHandler(log_file)
        logger.addHandler(hdlr)
        formatter = logging.Formatter('%(asctime)s %(levelname)s %(message)s')
        hdlr.setFormatter(formatter)
        return logger

    def gather_candidates(self, context):
        try:
            return self._do_gather(context)
        except Exception:
            self._log.exception("Error autocompleting %(complete_str)r" % context)

    def _do_gather(self, context):
        self._ctx = VimUtilCtx(self.vim)
        parameters = {}
        parameters['wordToComplete'] = context['complete_str']
        parameters['WantDocumentationForEveryCompletionResult'] = True

        response = getResponse(self._ctx, '/autocomplete', parameters,
                               json=True)

        vim_completions = []
        if response is not None:
            for completion in response:
                vim_completions.append({
                    'word': completion['CompletionText'],
                    'menu': completion['DisplayText'],
                    'info': ((completion['Description'] or ' ')
                             .replace('\r\n', '\n')),
                    'dup': 1,
                })

        return vim_completions
