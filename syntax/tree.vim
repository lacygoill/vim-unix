let b:current_syntax = 'tree'

syn match  treeConceal '─\s\zs.*/\ze.\{-}\%(\s->\s\|\%(\s->\s.*\)\@<!$\)' conceal
syn region treeDirectory matchgroup=Directory start='─\s\zs.*/\ze.\{-1,}' end='\ze/$' oneline concealends

hi link treeDirectory Directory
