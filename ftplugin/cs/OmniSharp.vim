if !get(g:, 'OmniSharp_loaded', 0) | finish | endif
if !OmniSharp#util#CheckCapabilities() | finish | endif
if get(b:, 'OmniSharp_ftplugin_loaded', 0) | finish | endif
let b:OmniSharp_ftplugin_loaded = 1

augroup OmniSharp_FileType
  autocmd! * <buffer>

  autocmd BufLeave <buffer>
  \   if !pumvisible()
  \|    call OmniSharp#UpdateBuffer()
  \|  endif

  autocmd CompleteDone <buffer> call OmniSharp#actions#complete#ExpandSnippet()
augroup END

setlocal omnifunc=OmniSharp#Complete

call OmniSharp#AppendCtrlPExtensions()

if get(g:, 'OmniSharp_start_server', 0) == 1
  call OmniSharp#StartServerIfNotRunning()
endif

command! -buffer -bar OmniSharpCodeFormat call OmniSharp#CodeFormat()
command! -buffer -bar OmniSharpFindImplementations call OmniSharp#FindImplementations()
command! -buffer -bar OmniSharpFindMembers call OmniSharp#FindMembers()
command! -buffer -bar -nargs=? OmniSharpFindSymbol call OmniSharp#FindSymbol(<q-args>)
command! -buffer -bar OmniSharpFindUsages call OmniSharp#FindUsages()
command! -buffer -bar OmniSharpFixUsings call OmniSharp#FixUsings()
command! -buffer -bar OmniSharpGetCodeActions call OmniSharp#GetCodeActions('normal')
command! -buffer -bar OmniSharpGlobalCodeCheck call OmniSharp#GlobalCodeCheck()
command! -buffer -bar OmniSharpGotoDefinition call OmniSharp#GotoDefinition()
command! -buffer -bar OmniSharpNavigateUp call OmniSharp#NavigateUp()
command! -buffer -bar OmniSharpNavigateDown call OmniSharp#NavigateDown()
command! -buffer -bar OmniSharpPreviewDefinition call OmniSharp#PreviewDefinition()
command! -buffer -bar OmniSharpPreviewImplementation call OmniSharp#PreviewImplementation()
command! -buffer -bar OmniSharpRename call OmniSharp#Rename()
command! -buffer -nargs=1 OmniSharpRenameTo call OmniSharp#RenameTo(<q-args>)
command! -buffer -bar OmniSharpRestartAllServers call OmniSharp#RestartAllServers()
command! -buffer -bar OmniSharpRestartServer call OmniSharp#RestartServer()
command! -buffer -bar OmniSharpRunTest call OmniSharp#RunTest()
command! -buffer -bar -nargs=* -complete=file OmniSharpRunTestsInFile call OmniSharp#RunTestsInFile(<f-args>)
command! -buffer -bar -nargs=? -complete=file OmniSharpStartServer call OmniSharp#StartServer(<q-args>)
command! -buffer -bar OmniSharpStopAllServers call OmniSharp#StopAllServers()
command! -buffer -bar OmniSharpStopServer call OmniSharp#StopServer()

command! -buffer -bar OmniSharpDocumentation call OmniSharp#actions#documentation#Documentation()
command! -buffer -bar OmniSharpHighlight call OmniSharp#actions#highlight#Buffer()
command! -buffer -bar OmniSharpHighlightEcho call OmniSharp#actions#highlight#Echo()
command! -buffer -bar OmniSharpSignatureHelp call OmniSharp#actions#signature#SignatureHelp()
command! -buffer -bar OmniSharpTypeLookup call OmniSharp#actions#documentation#TypeLookup()

nnoremap <buffer> <Plug>(omnisharp_code_format) :OmniSharpCodeFormat<CR>
nnoremap <buffer> <Plug>(omnisharp_documentation) :OmniSharpDocumentation<CR>
nnoremap <buffer> <Plug>(omnisharp_find_implementations) :OmniSharpFindImplementations<CR>
nnoremap <buffer> <Plug>(omnisharp_find_members) :OmniSharpFindMembers<CR>
nnoremap <buffer> <Plug>(omnisharp_find_symbol) :OmniSharpFindSymbol<CR>
nnoremap <buffer> <Plug>(omnisharp_find_usages) :OmniSharpFindUsages<CR>
nnoremap <buffer> <Plug>(omnisharp_fix_usings) :OmniSharpFixUsings<CR>
nnoremap <buffer> <Plug>(omnisharp_code_actions) :OmniSharpGetCodeActions<CR>
xnoremap <buffer> <Plug>(omnisharp_code_actions) :call OmniSharp#GetCodeActions('visual')<CR>
nnoremap <buffer> <Plug>(omnisharp_global_code_check) :OmniSharpGlobalCodeCheck<CR>
nnoremap <buffer> <Plug>(omnisharp_go_to_definition) :OmniSharpGotoDefinition<CR>
nnoremap <buffer> <Plug>(omnisharp_highlight) :OmniSharpHighlight<CR>
nnoremap <buffer> <Plug>(omnisharp_navigate_up) :OmniSharpNavigateUp<CR>
nnoremap <buffer> <Plug>(omnisharp_navigate_down) :OmniSharpNavigateDown<CR>
nnoremap <buffer> <Plug>(omnisharp_preview_definition) :OmniSharpPreviewDefinition<CR>
nnoremap <buffer> <Plug>(omnisharp_preview_implementation) :OmniSharpPreviewImplementation<CR>
nnoremap <buffer> <Plug>(omnisharp_rename) :OmniSharpRename<CR>
nnoremap <buffer> <Plug>(omnisharp_restart_server) :OmniSharpRestartServer<CR>
nnoremap <buffer> <Plug>(omnisharp_restart_all_servers) OmniSharpRestartAllServers<CR>
nnoremap <buffer> <Plug>(omnisharp_run_test) :OmniSharpRunTest<CR>
nnoremap <buffer> <Plug>(omnisharp_run_tests_in_file) :OmniSharpRunTestsInFile<CR>
nnoremap <buffer> <Plug>(omnisharp_signature_help) :OmniSharpSignatureHelp<CR>
inoremap <buffer> <Plug>(omnisharp_signature_help) <C-o>:OmniSharpSignatureHelp<CR>
nnoremap <buffer> <Plug>(omnisharp_start_server) :OmniSharpStartServer<CR>
nnoremap <buffer> <Plug>(omnisharp_stop_all_servers) :OmniSharpStopAllServers<CR>
nnoremap <buffer> <Plug>(omnisharp_stop_server) :OmniSharpStopServer<CR>
nnoremap <buffer> <Plug>(omnisharp_type_lookup) :OmniSharpTypeLookup<CR>

" The following commands and mappings have been renamed, but the old versions
" are kept here for backwards compatibility
command! -buffer -bar OmniSharpHighlightTypes call OmniSharp#actions#highlight#Buffer()
nnoremap <buffer> <Plug>(omnisharp_highlight_types) :OmniSharpHighlight<CR>
command! -buffer -bar OmniSharpHighlightEchoKind call OmniSharp#actions#highlight#Echo()

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= ' | '
else
  let b:undo_ftplugin = ''
endif
let b:undo_ftplugin .= '
\ execute "autocmd! OmniSharp_FileType * <buffer>"
\
\|  unlet b:OmniSharp_ftplugin_loaded
\|  delcommand OmniSharpCodeFormat
\|  delcommand OmniSharpDocumentation
\|  delcommand OmniSharpFindImplementations
\|  delcommand OmniSharpFindMembers
\|  delcommand OmniSharpFindSymbol
\|  delcommand OmniSharpFindUsages
\|  delcommand OmniSharpFixUsings
\|  delcommand OmniSharpGetCodeActions
\|  delcommand OmniSharpGlobalCodeCheck
\|  delcommand OmniSharpGotoDefinition
\|  delcommand OmniSharpHighlight
\|  delcommand OmniSharpHighlightEcho
\|  delcommand OmniSharpHighlightEchoKind
\|  delcommand OmniSharpHighlightTypes
\|  delcommand OmniSharpNavigateUp
\|  delcommand OmniSharpNavigateDown
\|  delcommand OmniSharpPreviewDefinition
\|  delcommand OmniSharpPreviewImplementation
\|  delcommand OmniSharpRename
\|  delcommand OmniSharpRenameTo
\|  delcommand OmniSharpRestartAllServers
\|  delcommand OmniSharpRestartServer
\|  delcommand OmniSharpRunTest
\|  delcommand OmniSharpRunTestsInFile
\|  delcommand OmniSharpSignatureHelp
\|  delcommand OmniSharpStartServer
\|  delcommand OmniSharpStopAllServers
\|  delcommand OmniSharpStopServer
\|  delcommand OmniSharpTypeLookup
\
\|  setlocal omnifunc< errorformat< makeprg<'

" vim:et:sw=2:sts=2
