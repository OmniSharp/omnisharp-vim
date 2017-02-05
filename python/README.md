# Python module for the plugin

The tests should be kept in the `tests` folder.

## Setup instructions for UNIX

The script `tox-bootstrap.sh` can be used for setting up a testing environment
on Linux and Mac machines.

The `tox` tool, when run, creates virtual environments under `.tox/` folder and
their names correspond the names in the `tox.ini` configuration file.  For
example, for activating a Python 2.7.x environment one would simply do:

```bash
source .tox/py27/bin/activate
```

## Setup instructions for Windows

TODO
