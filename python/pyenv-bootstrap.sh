#!/bin/bash

# Install pyenv by using this: https://github.com/yyuu/pyenv-installer
echo "Installing pyenv for easy setup of interpreters"
curl -L https://raw.githubusercontent.com/yyuu/pyenv-installer/master/bin/pyenv-installer | bash

echo "Do not forget to set the PATH for pyenv to work correctly afterwards!"

export PATH="${HOME}/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

echo "Setting up python interpreters for testing with tox"
echo "WARNING: this will take a long while the first time!"
for v in `cat .python-version`
do
    pyenv install $v
done
