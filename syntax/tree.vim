let b:current_syntax = 'tree'

syn match  treeConceal '─\s\zs.*/\ze.\{-}\%(\s->\s\|\%(\s->\s.*\)\@<!$\)' conceal
syn region treeDirectory matchgroup=Directory start='─\s\zs.*/\ze.\{-1,}' end='\ze/$' oneline concealends
syn match  treeDirectoryEndingSlash '/$'

" syn match treeFoo '─\s\zs.*/\ze.\{-1,}\s\[.\{-}\]'
" syn region treeFoo matchgroup=Directory start='─\s\zs.*/\ze.\{-1,}\s\[.\{-}\]' end='\ze/$' oneline concealends
" hi link treeFoo Directory

syn match treeExecutable '[^/]*\*$\|\%(->\s\)\@<=/.*\*$'
syn match treeLink '[^/]*\s->\s'

hi link  treeDirectory             Directory
hi link  treeDirectoryEndingSlash  Directory
hi link  treeExecutable            Comment
hi link  treeLink                  Identifier
