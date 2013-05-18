let s:save_cpo = &cpo
set cpo&vim

function! OmniSharp#complete#getCompletions(column, partialWord, textBuffer)
  " All of these functions take vim variable names as parameters
  let parameters = {}
  let parameters['column'] = a:column
  let parameters['wordToComplete'] = a:partialWord
  let parameters['buffer'] = join(a:textBuffer,"\r\n")
  let response = OmniSharp#request#autocomplete(parameters)
  let ret = []
  for completion in response
    let ret += [ {
          \ 'word' : completion.completiontext,
          \ 'abbr' : completion.displaytext,
          \ 'info': completion.description,
          \ 'icase' : 1,
          \ 'dup' : 1,
          \ } ]
  endfor
  return { 'candidates' : ret, 'response' : response }
endfunction

function! OmniSharp#complete#findimplementations()
  let response = OmniSharp#request#findimplementations()
  let ret = []
  if ! empty(response)
    for usage in response[0].locations
      let ret += [ {
            \ 'filename': fnamemodify(usage.filename,':.'),
            \ 'lnum': usage.line,
            \ 'col': usage.column,
            \ } ]
    endfor
  endif
  return { 'candidates' : ret, 'response' : response }
endfunction

function! OmniSharp#complete#findUsages()
  let response = OmniSharp#request#findusages()
  let ret = []
  if ! empty(response)
    for quickfix in response[0].usages
      let quickfix.filename = fnamemodify(quickfix.filename,":.")
      let ret += [ {
            \ 'filename': quickfix.filename,
            \ 'text': quickfix.text,
            \ 'lnum': quickfix.line,
            \ 'col': quickfix.column
            \ } ]
    endfor
  endif
  return { 'candidates' : ret, 'response' : response }
endfunction

function! OmniSharp#complete#findSyntaxErrors()
  let response = OmniSharp#request#syntaxerrors()
  let ret = []
  if ! empty(response)
    for err in response[0].errors
      let ret += [ {
            \ 'filename': err.filename,
            \ 'text': err.message,
            \ 'lnum': err.line,
            \ 'col': err.column,
            \ } ]
    endfor
  endif
  return { 'candidates' : ret, 'response' : response }
endfunction

function! OmniSharp#complete#build()
  let response = OmniSharp#request#build()
  let ret = []
  if ! empty(response[0].quickfixes)
    for quickfix in response[0].quickfixes
      let quickfix.filename = fnamemodify(quickfix.filename,":.")
      let ret += [ {
            \ 'filename': quickfix.filename,
            \ 'text': quickfix.text,
            \ 'lnum': quickfix.line,
            \ 'col': quickfix.column
            \ } ]
    endfor
  endif
  return { 'candidates' : ret, 'response' : response }
endfunction

let &cpo = s:save_cpo
unlet s:save_cpo
