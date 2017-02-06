#!/bin/bash

OMNISHARP_VENV="omnisharp-vim-venv-3.5.3"

export PATH="${HOME}/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
