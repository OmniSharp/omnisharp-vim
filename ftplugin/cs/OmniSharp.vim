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

augroup OmniSharp#FileType
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
command! -buffer -bar OmniSharpCodeFormat                          call OmniSharp#CodeFormat()
command! -buffer -bar OmniSharpDocumentation                       call OmniSharp#TypeLookupWithDocumentation()
command! -buffer -bar OmniSharpFindImplementations                 call OmniSharp#FindImplementations()
command! -buffer -bar OmniSharpFindMembers                         call OmniSharp#FindMembers()
command! -buffer -bar -nargs=? OmniSharpFindSymbol                 call OmniSharp#FindSymbol(<q-args>)
command! -buffer -bar OmniSharpFindUsages                          call OmniSharp#FindUsages()
command! -buffer -bar OmniSharpFixUsings                           call OmniSharp#FixUsings()
command! -buffer -bar OmniSharpGetCodeActions                      call OmniSharp#GetCodeActions('normal')
command! -buffer -bar OmniSharpGotoDefinition                      call OmniSharp#GotoDefinition()
command! -buffer -bar OmniSharpPreviewDefinition                   call OmniSharp#PreviewDefinition()
command! -buffer -bar OmniSharpPreviewImplementation               call OmniSharp#PreviewImplementation()
command! -buffer -bar OmniSharpHighlightTypes                      call OmniSharp#HighlightBuffer()
command! -buffer -bar OmniSharpNavigateUp                          call OmniSharp#NavigateUp()
command! -buffer -bar OmniSharpNavigateDown                        call OmniSharp#NavigateDown()
command! -buffer -bar OmniSharpOpenPythonLog                       call OmniSharp#OpenPythonLog()
command! -buffer -bar OmniSharpRename                              call OmniSharp#Rename()
command! -buffer -bar OmniSharpRestartAllServers                   call OmniSharp#RestartAllServers()
command! -buffer -bar OmniSharpRestartServer                       call OmniSharp#RestartServer()
command! -buffer -bar OmniSharpSignatureHelp                       call OmniSharp#SignatureHelp()
command! -buffer -bar -nargs=? -complete=file OmniSharpStartServer call OmniSharp#StartServer(<q-args>)
command! -buffer -bar OmniSharpStopAllServers                      call OmniSharp#StopAllServers()
command! -buffer -bar OmniSharpStopServer                          call OmniSharp#StopServer()
command! -buffer -bar OmniSharpTypeLookup                          call OmniSharp#TypeLookupWithoutDocumentation()
command! -buffer -bar -nargs=? OmniSharpInstall                    call OmniSharp#Install(<f-args>)

command! -buffer -nargs=1 OmniSharpRenameTo
\ call OmniSharp#RenameTo(<q-args>)

highlight default link csUserType Type
highlight default link csUserInterface Include
highlight default link csUserIdentifier Identifier

if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= ' | '
else
  let b:undo_ftplugin = ''
endif
let b:undo_ftplugin .= '
\ execute "autocmd! OmniSharp#FileType * <buffer>"
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
\
\|  setlocal omnifunc< errorformat< makeprg<'

" vim:et:sw=2:sts=2
