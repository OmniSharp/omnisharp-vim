### Running tests

These tests use the  [vader.vim](https://github.com/junegunn/vader.vim) plugin,
which needs to be installed alongside OmniSharp-vim.

To run a test, run the following from the command line:

```sh
vim -Nu mini-vimrc +Vader testfile.vader
```

To run all tests, run this command line:

```sh
vim -Nu mini-vimrc +Vader*
```
