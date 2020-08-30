""" omnisharp source for deoplete """
import logging
import os
import sys
from os.path import abspath, dirname, exists, join, pardir

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
        self.input_pattern = r'[^. \t0-9]\.\w*|\w+'
        self.is_volatile = True
        self.previous_input = ''

        vars = self.vim.vars

        vars['deoplete#source#omnisharp#_results'] = []
        vars['deoplete#source#omnisharp#_receivedResults'] = False

    def gather_candidates(self, context):
        vars = self.vim.vars

        if context['input'] == self.previous_input:
            if vars['deoplete#source#omnisharp#_receivedResults']:
                return vars['deoplete#source#omnisharp#_results']

            return []

        vars['deoplete#source#omnisharp#_receivedResults'] = False
        self.previous_input = context['input']

        self.vim.call('deoplete#source#omnisharp#sendRequest')
        return []

