if !get(g:, 'OmniSharp_loaded', 0)
  finish
endif

if !(has('python') || has('python3'))
  finish
endif

if get(b:, 'OmniSharp_ftplugin_loaded', 0)
  finish
endif
let b:OmniSharp_ftplugin_loaded = 1

if !exists('g:omnicomplete_fetch_full_documentation')
  let g:omnicomplete_fetch_full_documentation = 0
endif

augroup plugin-OmniSharp
  autocmd! * <buffer>

  autocmd BufLeave <buffer>
  \   if !pumvisible()
  \|    call OmniSharp#UpdateBuffer()
  \|  endif

  autocmd CompleteDone <buffer> call OmniSharp#ExpandAutoCompleteSnippet()
augroup END

setlocal omnifunc=OmniSharp#Complete

call OmniSharp#AppendCtrlPExtensions()

if get(g:, 'OmniSharp_start_server', 0) == 1
  call OmniSharp#StartServerIfNotRunning()
endif

" Commands
command! -buffer -bar OmniSharpBuildAsync          call OmniSharp#BuildAsync()
command! -buffer -bar OmniSharpCodeFormat          call OmniSharp#CodeFormat()
command! -buffer -bar OmniSharpDocumentation       call OmniSharp#TypeLookupWithDocumentation()
command! -buffer -bar OmniSharpFindImplementations call OmniSharp#FindImplementations()
command! -buffer -bar OmniSharpFindMembers         call OmniSharp#FindMembers()
command! -buffer -bar -nargs=? OmniSharpFindSymbol call OmniSharp#FindSymbol(<q-args>)
command! -buffer -bar OmniSharpFindUsages          call OmniSharp#FindUsages()
command! -buffer -bar OmniSharpFixUsings           call OmniSharp#FixUsings()
command! -buffer -bar OmniSharpGetCodeActions      call OmniSharp#GetCodeActions('normal')
command! -buffer -bar OmniSharpGotoDefinition      call OmniSharp#GotoDefinition()
command! -buffer -bar OmniSharpPreviewDefinition   call OmniSharp#PreviewDefinition()
command! -buffer -bar OmniSharpHighlightTypes      call OmniSharp#EnableTypeHighlighting()
command! -buffer -bar OmniSharpNavigateUp          call OmniSharp#NavigateUp()
command! -buffer -bar OmniSharpNavigateDown        call OmniSharp#NavigateDown()
command! -buffer -bar OmniSharpOpenPythonLog       call OmniSharp#OpenPythonLog()
command! -buffer -bar OmniSharpRename              call OmniSharp#Rename()
command! -buffer -bar OmniSharpRestartAllServers   call OmniSharp#RestartAllServers()
command! -buffer -bar OmniSharpRestartServer       call OmniSharp#RestartServer()
command! -buffer -bar OmniSharpRunAllTests         call OmniSharp#RunTests('all')
command! -buffer -bar OmniSharpRunLastTests        call OmniSharp#RunTests('last')
command! -buffer -bar OmniSharpRunTestFixture      call OmniSharp#RunTests('fixture')
command! -buffer -bar OmniSharpRunTests            call OmniSharp#RunTests('single')
command! -buffer -bar OmniSharpSignatureHelp       call OmniSharp#SignatureHelp()
command! -buffer -bar OmniSharpStartServer         call OmniSharp#StartServer()
command! -buffer -bar OmniSharpStopAllServers      call OmniSharp#StopAllServers()
command! -buffer -bar OmniSharpStopServer          call OmniSharp#StopServer()
command! -buffer -bar OmniSharpTypeLookup          call OmniSharp#TypeLookupWithoutDocumentation()
command! -buffer -bar -nargs=? OmniSharpInstall    call OmniSharp#Install(<f-args>)

command! -buffer -nargs=1 OmniSharpRenameTo
\ call OmniSharp#RenameTo(<q-args>)

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= ' | '
else
  let b:undo_ftplugin = ''
endif
let b:undo_ftplugin .= '
\ execute "autocmd! plugin-OmniSharp * <buffer>"
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
\|  delcommand OmniSharpGotoDefinition
\|  delcommand OmniSharpPreviewDefinition
\|  delcommand OmniSharpHighlightTypes
\|  delcommand OmniSharpInstall
\|  delcommand OmniSharpNavigateUp
\|  delcommand OmniSharpNavigateDown
\|  delcommand OmniSharpOpenPythonLog
\|  delcommand OmniSharpRename
\|  delcommand OmniSharpRenameTo
\|  delcommand OmniSharpRestartAllServers
\|  delcommand OmniSharpRestartServer
\|  delcommand OmniSharpSignatureHelp
\|  delcommand OmniSharpStartServer
\|  delcommand OmniSharpStopAllServers
\|  delcommand OmniSharpStopServer
\|  delcommand OmniSharpTypeLookup
\|  delcommand OmniSharpRunAllTests
\|  delcommand OmniSharpRunLastTests
\|  delcommand OmniSharpRunTestFixture
\|  delcommand OmniSharpRunTests
\
\|  setlocal omnifunc< errorformat< makeprg<'

" vim:et:sw=2:sts=2
