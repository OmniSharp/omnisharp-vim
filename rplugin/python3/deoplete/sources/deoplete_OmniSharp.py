
""" omnisharp source for deoplete """
import logging
import os
import sys
from os.path import abspath, dirname, exists, join, pardir
import re

from .base import Base

# This implementation was based off of the deoplete-lsp deoplete source
# Which is similar in that it calls lua to trigger a request, which receives a callback,
# then re-triggers deoplete autocomplete
class Source(Base):
    def __init__(self, vim):
        super().__init__(vim)

        self.name = 'omnisharp'
        self.mark = '[OS]'
        self.rank = 500
        self.filetypes = ['cs']
        # This pattern will trigger auto completion even if the typed text has not reached min_pattern_length
        self.input_pattern = r'[^. \t0-9]\.\w*'
        self.is_volatile = True
        self.previousLhs = ''
        self.partial = ''

    def parseInput(self, value):
        match = re.match(r"^(.*\W)(\w*)$", value)

        if match:
            groups = match.groups()
            return groups[0], groups[1]
        return None, None

    def gather_candidates(self, context):
        currentInput = context['input']

        lhs, partial = self.parseInput(currentInput)

        if lhs is None:
            return []

        if lhs != self.previousLhs or not partial.startswith(self.previousPartial):
            self.previousLhs = lhs
            self.previousPartial = partial
            self.vim.call('deoplete#source#omnisharp#sendRequest', lhs, partial)
            return []

        return self.vim.vars['deoplete#source#omnisharp#_results'] or []
