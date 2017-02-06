#!/bin/bash

. tox-env.sh

pyenv activate ${OMNISHARP_VENV}
tox
