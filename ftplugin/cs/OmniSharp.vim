if !get(g:, 'OmniSharp_loaded', 0) | finish | endif
if !OmniSharp#util#CheckCapabilities() | finish | endif
if get(b:, 'OmniSharp_ftplugin_loaded', 0) | finish | endif
let b:OmniSharp_ftplugin_loaded = 1

augroup OmniSharp_FileType
  autocmd! * <buffer>

  autocmd BufLeave <buffer>
  \ if !pumvisible() |
  \   call OmniSharp#actions#buffer#Update() |
  \ endif

  autocmd CompleteDone <buffer> call OmniSharp#actions#complete#ExpandSnippet()
augroup END

setlocal omnifunc=OmniSharp#Complete

if get(g:, 'OmniSharp_start_server', 0)
  call OmniSharp#StartServerIfNotRunning()
endif

command! -buffer -bar OmniSharpRestartAllServers call OmniSharp#RestartAllServers()
command! -buffer -bar OmniSharpRestartServer call OmniSharp#RestartServer()
command! -buffer -bar -nargs=? -complete=file OmniSharpStartServer call OmniSharp#StartServer(<q-args>)
command! -buffer -bar OmniSharpStopAllServers call OmniSharp#StopAllServers()
command! -buffer -bar OmniSharpStopServer call OmniSharp#StopServer()

command! -buffer -bar OmniSharpCodeFormat call OmniSharp#actions#format#Format()
command! -buffer -bar OmniSharpDocumentation call OmniSharp#actions#documentation#Documentation()
command! -buffer -bar OmniSharpFindImplementations call OmniSharp#actions#implementations#Find()
command! -buffer -bar OmniSharpFindMembers call OmniSharp#actions#members#Find()
command! -buffer -bar -nargs=? OmniSharpFindSymbol call OmniSharp#actions#symbols#Find(<q-args>)
command! -buffer -bar -nargs=? OmniSharpFindType call OmniSharp#actions#symbols#FindType(<q-args>)
command! -buffer -bar OmniSharpFindUsages call OmniSharp#actions#usages#Find()
command! -buffer -bar OmniSharpFixUsings call OmniSharp#actions#usings#Fix()
command! -buffer -bar OmniSharpGetCodeActions call OmniSharp#actions#codeactions#Get('normal')
command! -buffer -bar OmniSharpGlobalCodeCheck call OmniSharp#actions#diagnostics#CheckGlobal()
command! -buffer -bar -nargs=? OmniSharpGotoDefinition call OmniSharp#actions#definition#Find(<q-args>)
command! -buffer -bar OmniSharpHighlight call OmniSharp#actions#highlight#Buffer()
command! -buffer -bar OmniSharpHighlightEcho call OmniSharp#actions#highlight#Echo()
command! -buffer -bar OmniSharpNavigateUp call OmniSharp#actions#navigate#Up()
command! -buffer -bar OmniSharpNavigateDown call OmniSharp#actions#navigate#Down()
command! -buffer -bar OmniSharpPreviewDefinition call OmniSharp#actions#definition#Preview()
command! -buffer -bar OmniSharpPreviewImplementation call OmniSharp#actions#implementations#Preview()
command! -buffer -bar OmniSharpRename call OmniSharp#actions#rename#Prompt()
command! -buffer -nargs=1 OmniSharpRenameTo call OmniSharp#actions#rename#To(<q-args>)
command! -buffer -bar OmniSharpRepeatCodeAction call OmniSharp#actions#codeactions#Repeat('normal')
command! -buffer -bar OmniSharpRunTest call OmniSharp#actions#test#Run()
command! -buffer -bar -nargs=* -complete=file OmniSharpRunTestsInFile call OmniSharp#actions#test#RunInFile(<f-args>)
command! -buffer -bar OmniSharpSignatureHelp call OmniSharp#actions#signature#SignatureHelp()
command! -buffer -bar OmniSharpTypeLookup call OmniSharp#actions#documentation#TypeLookup()

nnoremap <buffer> <Plug>(omnisharp_code_format) :OmniSharpCodeFormat<CR>
nnoremap <buffer> <Plug>(omnisharp_documentation) :OmniSharpDocumentation<CR>
nnoremap <buffer> <Plug>(omnisharp_find_implementations) :OmniSharpFindImplementations<CR>
nnoremap <buffer> <Plug>(omnisharp_find_members) :OmniSharpFindMembers<CR>
nnoremap <buffer> <Plug>(omnisharp_find_symbol) :OmniSharpFindSymbol<CR>
nnoremap <buffer> <Plug>(omnisharp_find_type) :OmniSharpFindType<CR>
nnoremap <buffer> <Plug>(omnisharp_find_usages) :OmniSharpFindUsages<CR>
nnoremap <buffer> <Plug>(omnisharp_fix_usings) :OmniSharpFixUsings<CR>
nnoremap <buffer> <Plug>(omnisharp_code_actions) :OmniSharpGetCodeActions<CR>
xnoremap <buffer> <Plug>(omnisharp_code_actions) :call OmniSharp#actions#codeactions#Get('visual')<CR>
nnoremap <buffer> <Plug>(omnisharp_code_action_repeat) :OmniSharpRepeatCodeAction<CR>
xnoremap <buffer> <Plug>(omnisharp_code_action_repeat) :call OmniSharp#actions#codeactions#Repeat('visual')<CR>
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
\| unlet b:OmniSharp_ftplugin_loaded
\| delcommand OmniSharpCodeFormat
\| delcommand OmniSharpDocumentation
\| delcommand OmniSharpFindImplementations
\| delcommand OmniSharpFindMembers
\| delcommand OmniSharpFindSymbol
\| delcommand OmniSharpFindType
\| delcommand OmniSharpFindUsages
\| delcommand OmniSharpFixUsings
\| delcommand OmniSharpGetCodeActions
\| delcommand OmniSharpGlobalCodeCheck
\| delcommand OmniSharpGotoDefinition
\| delcommand OmniSharpHighlight
\| delcommand OmniSharpHighlightEcho
\| delcommand OmniSharpHighlightEchoKind
\| delcommand OmniSharpHighlightTypes
\| delcommand OmniSharpNavigateUp
\| delcommand OmniSharpNavigateDown
\| delcommand OmniSharpPreviewDefinition
\| delcommand OmniSharpPreviewImplementation
\| delcommand OmniSharpRename
\| delcommand OmniSharpRenameTo
\| delcommand OmniSharpRepeatCodeAction
\| delcommand OmniSharpRestartAllServers
\| delcommand OmniSharpRestartServer
\| delcommand OmniSharpRunTest
\| delcommand OmniSharpRunTestsInFile
\| delcommand OmniSharpSignatureHelp
\| delcommand OmniSharpStartServer
\| delcommand OmniSharpStopAllServers
\| delcommand OmniSharpStopServer
\| delcommand OmniSharpTypeLookup
\
\| setlocal omnifunc<'

" vim:et:sw=2:sts=2
