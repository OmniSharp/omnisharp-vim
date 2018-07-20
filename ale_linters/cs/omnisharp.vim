function! ale_linters#cs#omnisharp#ProcessOutput(buffer, lines) abort
  let list = []
  for line in a:lines
    let [filename, lnum, col, type, subtype, text] = split(line, '@@@')
    let item = {
          \ "filename": filename,
          \ "lnum": lnum,
          \ "col": col,
          \ "type": type,
          \ "text": text,
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
        \ 'python %s --filename %%s --host %s --level %s --cwd %s --delimiter @@@',
        \ ale#Escape(linter), ale#Escape(host), g:OmniSharp_loglevel, ale#Escape(getcwd()))
  if g:OmniSharp_translate_cygwin_wsl
    cmd = cmd . ' --translate'
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
