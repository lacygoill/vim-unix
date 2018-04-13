let b:current_syntax = 'tree'

" Syntax {{{1

syn match  treeOnlyLastComponent '─\s\zs.*/\ze.*\%(\s->\s\|\%(\s->\s.*\)\@<!$\)' conceal

syn region treeDirectory matchgroup=Directory start='─\s\zs.*/\ze.\{-1,}' end='\ze/$' oneline concealends
syn match  treeDirectoryEndingSlash '/$'
syn region treeDirectoryNotOpened matchgroup=WarningMsg start='─\s\zs.*/\ze.\{-}/' end='\ze\s\[.\{-}\]$' concealends oneline

"                         ┌ simple executable:
"                         │
"                         │         my_script*
"                         │         ^^^^^^^^^^
"                         │
"                         │
"                         │         ┌ full path to executable in a symlink:
"                         │         │
"                         │         │         /bin/mt -> /etc/alternatives/mt*
"                         │         │                    ^^^^^^^^^^^^^^^^^^^^^
"                         ├──────┐  ├───────────────────┐
syn match treeExecutable '[^/]*\*$\|\%(\s->\s\)\@<=/.*\*$'
syn match treeLink '[^/]*\s->\s'
"                   └───┤
"                       └ last path component of a symlink:
"
"                                 /proc/11201/exe -> /usr/lib/firefox/firefox*
"                                             ^^^^^^^

" Colors {{{1

hi treeLink        ctermfg=darkmagenta guifg=darkmagenta
hi treeExecutable  ctermfg=darkgreen   guifg=darkgreen

hi link  treeDirectory             Directory
hi link  treeDirectoryEndingSlash  Directory
hi link  treeDirectoryNotOpened    WarningMsg

