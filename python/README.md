# Python module for the plug-in

The tests should be kept in the `tests` folder.

## Setup

Install `tox` system wide and just run the `tox` command from the command line.
It should succeed if you have the following:

- any version of the Python 2.7 interpreter

Using the python then should be as simple as:

```bash
source .tox/${PYTHON_VERSION_LABEL}/bin/activate
```

## Setup instructions for pyenv for UNIX

The script `pyenv-bootstrap.sh` can be used for setting up different versions
of the interpreters on Linux and Mac machines.

Unfortunately `pyenv` is not supported on Windows, so you will need to install
the interpreters manually.
