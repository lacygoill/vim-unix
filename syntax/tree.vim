let b:current_syntax = 'tree'

" Syntax {{{1

syn match  treeOnlyLastComponent '─\s\zs.*/' conceal

syn region treeDirectory matchgroup=Directory start='─\s\zs.*/\ze.\+' end='/$' oneline concealends contains=treeLink
syn region treeDirectoryNotOpened matchgroup=WarningMsg start='─\s\zs.*/\ze.*/' end='\ze\s\[.\{-}\]$' concealends oneline

"                         ┌ simple executable:
"                         │
"                         │         my_script*
"                         │         ^^^^^^^^^^
"                         │
"                         │            ┌ full path to executable in a symlink:
"                         │            │
"                         │            │         /bin/mt -> /etc/alternatives/mt*
"                         │            │                    ^^^^^^^^^^^^^^^^^^^^^
"                         ├─────────┐  ├──────────────────────┐
syn match treeExecutable '[^/]*\ze\*$\|\%(\s->\s\)\@<=/.*\ze\*$'
syn match treeConcealStar '\*$' conceal
syn match treeLink '[^/]*\s->\s' contained
"                   ├───┘
"                   └ last path component of a symlink:
"
"                             /proc/11201/exe -> /usr/lib/firefox/firefox*
"                                         ^^^^^^^

" Colors {{{1

hi treeLink        ctermfg=darkmagenta guifg=darkmagenta
hi treeExecutable  ctermfg=darkgreen   guifg=darkgreen

hi link  treeDirectory             Directory
hi link  treeDirectoryEndingSlash  Directory
hi link  treeDirectoryNotOpened    WarningMsg

