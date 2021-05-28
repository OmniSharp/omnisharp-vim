let s:save_cpo = &cpoptions
set cpoptions&vim

" This function returns a count of the currently available code actions. It also
" uses the code actions to pre-populate the code actions for
" OmniSharp#actions#codeactions#Get, and clears them on CursorMoved.
"
" If a single callback function is passed in, the callback will be called on
" CursorMoved, allowing this function to be used to set up a temporary "Code
" actions available" flag, e.g. in the statusline or signs column, and the
" callback function can be used to clear the flag.
"
" If a dict is passed in, the dict may contain one or both of 'CallbackCleanup'
" and 'CallbackCount' Funcrefs. 'CallbackCleanup' is the single callback
" function mentioned above. 'CallbackCount' is called after a response with the
" number of actions available.
"
" call OmniSharp#CountCodeActions({-> execute('sign unplace 99')})
" call OmniSharp#CountCodeActions({
" \ 'CallbackCleanup': {-> execute('sign unplace 99')},
" \ 'CallbackCount': function('PlaceSign')
" \}
function! OmniSharp#actions#codeactions#Count(...) abort
  if a:0 && type(a:1) == type(function('tr'))
    let opts = { 'CallbackCleanup': a:1 }
  elseif a:0 && type(a:1) == type({})
    let opts = a:1
  else
    let opts = {}
  endif
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBCountCodeActions', [opts])
    call s:StdioGet('normal', Callback)
  else
    let actions = OmniSharp#py#Eval('getCodeActions("normal")')
    if OmniSharp#py#CheckForError() | return | endif
    call s:CBCountCodeActions(opts, actions)
  endif
endfunction

function! s:StdioGet(mode, Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioGetRH', [a:Callback]),
  \ 'SavePosition': 1
  \}
  call s:PrepareParameters(opts, a:mode)
  call OmniSharp#stdio#Request('/v2/getcodeactions', opts)
endfunction

function! s:PrepareParameters(opts, mode) abort
  if a:mode ==# 'visual'
    let start = getpos("'<")
    let end = getpos("'>")
    " In visual line mode, getpos("'>")[2] is a large number (2147483647).
    " When this value is too large, use the length of the line as the column
    " position.
    if end[2] > 99999
      let end[2] = len(getline(end[1]))
    endif
    let s:codeActionParameters = {
    \ 'Selection': {
    \   'Start': {
    \     'Line': start[1],
    \     'Column': start[2]
    \   },
    \   'End': {
    \     'Line': end[1],
    \     'Column': end[2]
    \   }
    \ }
    \}
    let a:opts.Parameters = s:codeActionParameters
  else
    if exists('s:codeActionParameters')
      unlet s:codeActionParameters
    endif
  endif
endfunction

function! s:StdioGetRH(Callback, response) abort
  if !a:response.Success | return | endif
  call a:Callback(a:response.Body.CodeActions)
endfunction

function! s:CBCountCodeActions(opts, actions) abort
  let s:actions = a:actions
  if has_key(a:opts, 'CallbackCount')
    call a:opts.CallbackCount(len(s:actions))
  endif
  let s:Cleanup = function('s:CleanupCodeActions', [a:opts])
  augroup OmniSharp_CountCodeActions
    autocmd!
    autocmd CursorMoved <buffer> call s:Cleanup()
    autocmd CursorMovedI <buffer> call s:Cleanup()
    autocmd BufLeave <buffer> call s:Cleanup()
  augroup END
  return len(s:actions)
endfunction


function! OmniSharp#actions#codeactions#Get(mode) range abort
  if exists('s:actions')
    call s:CBGetCodeActions(a:mode, s:actions)
  elseif g:OmniSharp_server_stdio
    let Callback = function('s:CBGetCodeActions', [a:mode])
    call s:StdioGet(a:mode, Callback)
  else
    let command = printf('getCodeActions(%s)', string(a:mode))
    let actions = OmniSharp#py#Eval(command)
    if OmniSharp#py#CheckForError() | return | endif
    call s:CBGetCodeActions(a:mode, actions)
  endif
endfunction

function! s:CleanupCodeActions(opts) abort
  unlet s:actions
  unlet s:Cleanup
  if has_key(a:opts, 'CallbackCleanup')
    call a:opts.CallbackCleanup()
  endif
  autocmd! OmniSharp_CountCodeActions
endfunction

function! s:CBGetCodeActions(mode, actions) abort
  if empty(a:actions)
    echo 'No code actions found'
    return
  endif
  if g:OmniSharp_selector_ui ==? 'unite'
    let context = {'empty': 0, 'auto_resize': 1}
    call unite#start([['OmniSharp/findcodeactions', a:mode, a:actions]], context)
  elseif g:OmniSharp_selector_ui ==? 'ctrlp'
    call ctrlp#OmniSharp#findcodeactions#setactions(a:mode, a:actions)
    call ctrlp#init(ctrlp#OmniSharp#findcodeactions#id())
  elseif g:OmniSharp_selector_ui ==? 'fzf'
    call fzf#OmniSharp#GetCodeActions(a:mode, a:actions)
  elseif g:OmniSharp_selector_ui ==? 'clap'
    call clap#OmniSharp#GetCodeActions(a:mode, a:actions)
  else
    let message = []
    let i = 0
    for action in a:actions
      let i += 1
      call add(message, printf(' %2d. %s', i, action.Name))
    endfor
    call add(message, 'Enter an action number, or just hit Enter to cancel: ')
    let selection = str2nr(input(join(message, "\n")))
    if type(selection) == type(0) && selection > 0 && selection <= i
      let action = a:actions[selection - 1]
      if g:OmniSharp_server_stdio
        call OmniSharp#actions#codeactions#Run(action)
      else
        let command = substitute(get(action, 'Identifier'), '''', '\\''', 'g')
        let command = printf('runCodeAction(''%s'', ''%s'')', a:mode, command)
        let action = OmniSharp#py#Eval(command)
        if OmniSharp#py#CheckForError() | return | endif
        if !action
          echo 'No action taken'
        endif
      endif
    endif
  endif
endfunction


function! OmniSharp#actions#codeactions#Repeat(mode) abort
  if !g:OmniSharp_server_stdio
    echomsg 'This functionality is only available with the stdio server'
    return
  endif
  if !exists('s:lastCodeActionIdentifier')
    echomsg 'There is no last code action to repeat'
    return
  endif
  call s:PrepareParameters({}, a:mode)
  let RH = function('OmniSharp#buffer#PerformChanges', [{}])
  call s:RunCodeAction(s:lastCodeActionIdentifier, 1, RH)
endfunction

function! OmniSharp#actions#codeactions#Run(action, ...) abort
  let RH = function('OmniSharp#buffer#PerformChanges', [a:0 ? a:1 : {}])
  let s:lastCodeActionIdentifier = a:action.Identifier
  call s:RunCodeAction(a:action.Identifier, 0, RH)
endfunction

function! s:RunCodeAction(identifier, repeating, ResponseHandler) abort
  let opts = {
  \ 'ResponseHandler': a:ResponseHandler,
  \ 'Parameters': {
  \   'Identifier': a:identifier,
  \   'WantsTextChanges': 1,
  \   'WantsAllCodeActionOperations': 1
  \ },
  \ 'UsePreviousPosition': !a:repeating
  \}
  if exists('s:codeActionParameters')
    call extend(opts.Parameters, s:codeActionParameters, 'force')
  endif
  call OmniSharp#stdio#Request('/v2/runcodeaction', opts)
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
