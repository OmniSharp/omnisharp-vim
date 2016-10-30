#!/bin/bash

# setup various python interpreters (this will take a long while the first time)
for v in `cat .python-version`
do
    pyenv install $v
done
