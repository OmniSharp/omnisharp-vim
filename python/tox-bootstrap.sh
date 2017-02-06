#!/bin/bash

# Install pyenv by using this: https://github.com/yyuu/pyenv-installer
echo "Installing pyenv"
curl -L https://raw.githubusercontent.com/yyuu/pyenv-installer/master/bin/pyenv-installer | bash

. ./tox-env.sh

echo "Setting up python interpreters for testing with tox"
echo "WARNING: this will take a long while the first time!"
for v in `cat .python-version`
do
    pyenv install $v
done

pyenv virtualenv 3.5.3 ${OMNISHARP_VENV}
pyenv activate ${OMNISHARP_VENV}
pip install --upgrade setuptools pip tox
