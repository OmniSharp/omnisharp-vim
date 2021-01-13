let s:save_cpo = &cpoptions
set cpoptions&vim


" Accepts a Funcref callback argument, to be called after the response is
" returned (synchronously or asynchronously) with the number of usages
function! OmniSharp#actions#usages#Find(...) abort
  let opts = a:0 && a:1 isnot 0 ? { 'Callback': a:1 } : {}
  let target = expand('<cword>')
  let Callback = function('s:CBFindUsages', [target, opts])
  return s:FindUsages(Callback)
endfunction

function! OmniSharp#actions#usages#OpenAll(...) abort
  let fname = expand('%:p')
  let cmd = (a:0 && type(a:1) == type('') && len(a:1)) ? a:1 : 'tabedit'
  let Callback = function('s:CBOpenAllUsages', [fname, cmd])
  return s:FindUsages(Callback)
endfunction

function! s:FindUsages(Callback) abort
  let target = expand('<cword>')
  if g:OmniSharp_server_stdio
    let Callback = function('s:CBFindUsages', [target, {}])
    call s:StdioFind(a:Callback)
  else
    let locs = OmniSharp#py#Eval('findUsages()')
    if OmniSharp#py#CheckForError() | return | endif
    let ret = a:Callback(locs)
    return ret
  endif
endfunction

function! s:StdioFind(Callback) abort
  let opts = {
  \ 'ResponseHandler': function('s:StdioFindRH', [a:Callback]),
  \ 'Parameters': {
  \   'ExcludeDefinition': 1
  \ }
  \}
  call OmniSharp#stdio#Request('/findusages', opts)
endfunction

function! s:StdioFindRH(Callback, response) abort
  if !a:response.Success | return | endif
  let usages = a:response.Body.QuickFixes
  if type(usages) == type([])
    call a:Callback(OmniSharp#locations#Parse(usages))
  else
    call a:Callback([])
  endif
endfunction

function! s:CBFindUsages(target, opts, locations) abort
  let numUsages = len(a:locations)
  if numUsages == 0
    echo 'No usages found'
  elseif get(g:, 'OmniSharp_selector_findusages', '') ==? 'fzf'
    call fzf#OmniSharp#FindUsages(a:locations, a:target)
  elseif get(g:, 'OmniSharp_selector_findusages', '') ==? 'clap'
    call clap#OmniSharp#FindUsages(a:locations, a:target)
  else
    call OmniSharp#locations#SetQuickfix(a:locations, 'Usages: ' . a:target)
  endif
  if has_key(a:opts, 'Callback')
    call a:opts.Callback(numUsages)
  endif
  return numUsages
endfunction

function! s:CBOpenAllUsages(fname, cmd, locations) abort
  if len(a:locations) == 0
    echo 'No usages found'
    return
  endif
  let restoreAutochdir = 0
  if &autochdir
    let restoreAutochdir = 1
    set noautochdir
  endif
  let opennames = {}
  for bufObj in getbufinfo({'bufloaded': 1, 'buflisted': 1})
    let opennames[bufObj.name] = 0
  endfor
  let filenames = {}
  for location in a:locations
    let absName = fnamemodify(location.filename, ':p')
    if !has_key(opennames, absName) && a:fname !=? absName && !has_key(filenames, absName)
      let filenames[absName] = location
    endif
  endfor
  for name in keys(filenames)
    call OmniSharp#locations#NavigateWith(filenames[name], a:cmd)
  endfor
  if restoreAutochdir
    set autochdir
  endif
endfunction

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:et:sw=2:sts=2
