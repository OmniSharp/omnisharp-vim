if !get(g:, 'OmniSharp_loaded', 0)
  finish
endif

let s:delimiter = '@@@'

function! ale_linters#cs#omnisharp#ProcessOutput(buffer, lines) abort
  let list = []
  for line in a:lines
    let [filename, lnum, col, type, subtype, text] = split(line, s:delimiter)
    let item = {
          \ 'filename': filename,
          \ 'lnum': lnum,
          \ 'col': col,
          \ 'type': type,
          \ 'text': text,
          \}
    if subtype ==? 'style'
      let item['sub_type'] = 'style'
    endif
    call add(list, item)
  endfor
  return list
endfunction

function! ale_linters#cs#omnisharp#GetCommand(bufnum) abort
  let linter = OmniSharp#util#path_join(['python', 'ale_lint.py'])
  let host = OmniSharp#GetHost(a:bufnum)
  let cmd = printf(
        \ '%%e %s --filename %%s --host %s --level %s --cwd %s --delimiter %s --encoding %s',
        \ ale#Escape(linter), ale#Escape(host), ale#Escape(g:OmniSharp_loglevel),
        \ ale#Escape(getcwd()), ale#Escape(s:delimiter), &encoding)
  if g:OmniSharp_translate_cygwin_wsl
    let cmd = cmd . ' --translate'
  endif
  return cmd
endfunction

call ale#linter#Define('cs', {
\   'name': 'omnisharp',
\   'aliases': ['Omnisharp', 'OmniSharp'],
\   'executable': 'python',
\   'command_callback': 'ale_linters#cs#omnisharp#GetCommand',
\   'callback': 'ale_linters#cs#omnisharp#ProcessOutput',
\})

" vim:et:sw=2:sts=2
