# Python module for the plug-in

The tests should be kept in the `tests` folder.

## Setup

Pip should is bundled with recent releases of Python (`2.7.9+` and `3.4`) [[StackOverflow](https://stackoverflow.com/a/12476379)], hence the easiest way to set `tox` up is via `pip` unless a system package manager is your preferred choice.
Instructions:

- Install the latest Python `2.7.x` release from [python.org](https://www.python.org/downloads/).
- Install `tox`:
    - Via `pip` from command prompt or terminal application:
    ```
    $ pip install tox
    ```
    - Via your own package manager.

## Activating the tox virtual environments

In order to activate a specific python environment configured with `tox` execute the following:

```bash
source .tox/${PYTHON_VERSION_LABEL}/bin/activate
```

## Setup instructions for pyenv for UNIX

The script `pyenv-bootstrap.sh` can be used for setting up different versions
of the interpreters on Linux and Mac machines.

Unfortunately `pyenv` is not supported on Windows, so you will need to install
the interpreters manually.
