let b:current_syntax = 'tree'

syn match  treeShortenFullPath '─\s\zs.*/\ze.*\%(\s->\s\|\%(\s->\s.*\)\@<!$\)' conceal
syn region treeDirectory matchgroup=Directory start='─\s\zs.*/\ze.\{-1,}' end='\ze/$' oneline concealends
syn match  treeDirectoryEndingSlash '/$'
syn region treeDirectoryNotOpened matchgroup=WarningMsg start='─\s\zs.*/\ze.\{-}/' end='\ze\s\[.\{-}\]$' concealends oneline

syn match treeExecutable '[^/]*\*$\|\%(->\s\)\@<=/.*\*$'
syn match treeLink '[^/]*\s->\s'

hi link  treeDirectory             Directory
hi link  treeDirectoryEndingSlash  Directory
hi link  treeDirectoryNotOpened    WarningMsg
hi link  treeExecutable            Comment
hi link  treeLink                  Identifier

