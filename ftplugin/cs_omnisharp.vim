
"Set a default value for the server address
if !exists('g:OmniSharp_host')
	let g:OmniSharp_host='http://localhost:2000'
endif

" Auto syntax check.
augroup plugin-OmniSharp-SyntaxCheck
	autocmd! * <buffer>
	autocmd BufWritePre <buffer>
    \   if g:OmniSharp_BufWritePreSyntaxCheck
    \|      let b:OmniSharp_SyntaxChecked = 1
	\|		call OmniSharp#FindSyntaxErrors()
	\|	else
	\|		let b:OmniSharp_SyntaxChecked = 0
	\|	endif

	autocmd CursorHold <buffer>
	\	if g:OmniSharp_CursorHoldSyntaxCheck && !get(b:, "OmniSharp_SyntaxChecked", 0)
	\|		let b:OmniSharp_SyntaxChecked = 1
	\|		call OmniSharp#FindSyntaxErrors()
	\|	endif
augroup END

" Commands
command! -buffer -bar OmniSharpFindType            call ctrlp#init(findtype#id())
command! -buffer -bar OmniSharpFindSymbol         call ctrlp#init(findsymbols#id())
command! -buffer -bar OmniSharpFindMembers         call OmniSharp#FindMembers()
command! -buffer -bar OmniSharpFindUsages          call OmniSharp#FindUsages()
command! -buffer -bar OmniSharpFindImplementations call OmniSharp#FindImplementations()
command! -buffer -bar OmniSharpGotoDefinition      call OmniSharp#GotoDefinition()
command! -buffer -bar OmniSharpFindSyntaxErrors    call OmniSharp#FindSyntaxErrors()
command! -buffer -bar OmniSharpGetCodeActions      call OmniSharp#GetCodeActions()
command! -buffer -bar OmniSharpTypeLookup          call OmniSharp#TypeLookup()
command! -buffer -bar OmniSharpBuild               call OmniSharp#Build()
command! -buffer -bar OmniSharpBuildAsync          call OmniSharp#BuildAsync()
command! -buffer -bar OmniSharpRename              call OmniSharp#Rename()
command! -buffer -bar OmniSharpReloadSolution      call OmniSharp#ReloadSolution()
command! -buffer -bar OmniSharpCodeFormat          call OmniSharp#CodeFormat()
command! -buffer -bar OmniSharpStartServer         call OmniSharp#StartServer()
command! -buffer -bar OmniSharpStopServer          call OmniSharp#StopServer()
command! -buffer -bar OmniSharpAddToProject        call OmniSharp#AddToProject()
command! -buffer -bar OmniSharpHighlightTypes      call OmniSharp#EnableTypeHighlighting()


command! -buffer -nargs=1 OmniSharpRenameTo
\	call OmniSharp#RenameTo(<q-args>)

command! -buffer -nargs=1 -complete=file
\	OmniSharpStartServerSolution
\	call OmniSharp#StartServerSolution(<q-args>)

command! -buffer -nargs=1 -complete=file OmniSharpAddReference         
\   call OmniSharp#AddReference(<q-args>)

setlocal omnifunc=OmniSharp#Complete



if exists('b:undo_ftplugin')
	let b:undo_ftplugin .= ' | '
else
	let b:undo_ftplugin = ''
endif
let b:undo_ftplugin .= '
\	execute "autocmd! plugin-OmniSharp-SyntaxCheck * <buffer>"
\
\|	delcommand OmniSharpFindType
\|	delcommand OmniSharpFindSymbol
\|	delcommand OmniSharpFindUsages
\|	delcommand OmniSharpFindImplementations
\|	delcommand OmniSharpGotoDefinition
\|	delcommand OmniSharpFindSyntaxErrors
\|	delcommand OmniSharpGetCodeActions
\|	delcommand OmniSharpTypeLookup
\|	delcommand OmniSharpBuild
\|	delcommand OmniSharpBuildAsync
\|	delcommand OmniSharpRename
\|	delcommand OmniSharpReloadSolution
\|	delcommand OmniSharpCodeFormat
\|	delcommand OmniSharpStartServer
\|	delcommand OmniSharpStopServer
\|	delcommand OmniSharpAddToProject
\
\|	delcommand OmniSharpRenameTo
\|	delcommand OmniSharpStartServerSolution
\|	delcommand OmniSharpAddReference
\
\|	setlocal omnifunc< errorformat< makeprg<'
