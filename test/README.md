### Running tests

These tests use the [vader.vim](https://github.com/junegunn/vader.vim) plugin,
which needs to be installed alongside OmniSharp-vim.

To run a test, open a .vader file and run `:Vader`, or run the following from
the command line:

```sh
vim -u vimrc -c 'Vader! testfile.vader'
```

To run all tests, run this command line:

```sh
vim -u vimrc -c 'Vader! *'
```
