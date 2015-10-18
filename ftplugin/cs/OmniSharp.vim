if !has('python')
  finish
endif

if get(b:, 'OmniSharp_ftplugin_loaded', 0)
  finish
endif
let b:OmniSharp_ftplugin_loaded = 1

"Set a default value for the server address
if !exists('g:omnicomplete_fetch_full_documentation')
    let g:omnicomplete_fetch_full_documentation = 0
endif

augroup plugin-OmniSharp
  autocmd! * <buffer>

  autocmd BufLeave <buffer>
  \   if !pumvisible()
  \|    call OmniSharp#UpdateBuffer()
  \|  endif

augroup END

setlocal omnifunc=OmniSharp#Complete

call OmniSharp#AppendCtrlPExtensions()

if get(g:, 'Omnisharp_start_server', 0) == 1
  call OmniSharp#StartServerIfNotRunning()
endif

" Commands
command! -buffer -bar OmniSharpAddToProject        call OmniSharp#AddToProject()
command! -buffer -bar OmniSharpBuild               call OmniSharp#Build()
command! -buffer -bar OmniSharpBuildAsync          call OmniSharp#BuildAsync()
command! -buffer -bar OmniSharpCodeFormat          call OmniSharp#CodeFormat()
command! -buffer -bar OmniSharpDocumentation       call OmniSharp#TypeLookupWithDocumentation()
command! -buffer -bar OmniSharpFindImplementations call OmniSharp#FindImplementations()
command! -buffer -bar OmniSharpFindMembers         call OmniSharp#FindMembers()
command! -buffer -bar OmniSharpFindSymbol          call OmniSharp#FindSymbol()
command! -buffer -bar OmniSharpFindSyntaxErrors    call OmniSharp#FindSyntaxErrors()
command! -buffer -bar OmniSharpFindType            call OmniSharp#FindType()
command! -buffer -bar OmniSharpFindUsages          call OmniSharp#FindUsages()
command! -buffer -bar OmniSharpFixIssue            call OmniSharp#FixIssue()
command! -buffer -bar OmniSharpFixUsings           call OmniSharp#FixUsings()
command! -buffer -bar OmniSharpGetCodeActions      call OmniSharp#GetCodeActions('normal')
command! -buffer -bar OmniSharpGotoDefinition      call OmniSharp#GotoDefinition()
command! -buffer -bar OmniSharpHighlightTypes      call OmniSharp#EnableTypeHighlighting()
command! -buffer -bar OmniSharpNavigateUp          call OmniSharp#NavigateUp()
command! -buffer -bar OmniSharpNavigateDown        call OmniSharp#NavigateDown()
command! -buffer -bar OmniSharpReloadSolution      call OmniSharp#ReloadSolution()
command! -buffer -bar OmniSharpRename              call OmniSharp#Rename()
command! -buffer -bar OmniSharpRunAllTests         call OmniSharp#RunTests('all')
command! -buffer -bar OmniSharpRunLastTests        call OmniSharp#RunTests('last')
command! -buffer -bar OmniSharpRunTestFixture      call OmniSharp#RunTests('fixture')
command! -buffer -bar OmniSharpRunTests            call OmniSharp#RunTests('single')
command! -buffer -bar OmniSharpStartServer         call OmniSharp#StartServer()
command! -buffer -bar OmniSharpStopServer          call OmniSharp#StopServer()
command! -buffer -bar OmniSharpTypeLookup          call OmniSharp#TypeLookupWithoutDocumentation()


command! -buffer -nargs=1 OmniSharpRenameTo
\ call OmniSharp#RenameTo(<q-args>)

command! -buffer -nargs=1 -complete=file
\ OmniSharpStartServerSolution
\ call OmniSharp#StartServerSolution(<q-args>)

command! -buffer -nargs=1 -complete=file OmniSharpAddReference
\ call OmniSharp#AddReference(<q-args>)


if exists('b:undo_ftplugin')
  let b:undo_ftplugin .= ' | '
else
  let b:undo_ftplugin = ''
endif
let b:undo_ftplugin .= '
\ execute "autocmd! plugin-OmniSharp * <buffer>"
\
\|  unlet b:OmniSharp_ftplugin_loaded
\|  delcommand OmniSharpAddReference
\|  delcommand OmniSharpAddToProject
\|  delcommand OmniSharpBuild
\|  delcommand OmniSharpBuildAsync
\|  delcommand OmniSharpCodeFormat
\|  delcommand OmniSharpDocumentation
\|  delcommand OmniSharpFindImplementations
\|  delcommand OmniSharpFindMembers
\|  delcommand OmniSharpFindSymbol
\|  delcommand OmniSharpFindSyntaxErrors
\|  delcommand OmniSharpFindType
\|  delcommand OmniSharpFindUsages
\|  delcommand OmniSharpFixIssue
\|  delcommand OmniSharpFixUsings
\|  delcommand OmniSharpGetCodeActions
\|  delcommand OmniSharpGotoDefinition
\|  delcommand OmniSharpHighlightTypes
\|  delcommand OmniSharpNavigateUp
\|  delcommand OmniSharpNavigateDown
\|  delcommand OmniSharpReloadSolution
\|  delcommand OmniSharpRename
\|  delcommand OmniSharpRenameTo
\|  delcommand OmniSharpStartServer
\|  delcommand OmniSharpStartServerSolution
\|  delcommand OmniSharpStopServer
\|  delcommand OmniSharpTypeLookup
\|  delcommand OmniSharpRunAllTests
\|  delcommand OmniSharpRunLastTests
\|  delcommand OmniSharpRunTestFixture
\|  delcommand OmniSharpRunTests
\
\|  setlocal omnifunc< errorformat< makeprg<'
