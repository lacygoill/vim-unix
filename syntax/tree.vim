let b:current_syntax = 'tree'

" Syntax {{{1

syn match  treeOnlyLastComponent  '─\s\zs.*/\%(.\{-}[^/]\)\@='  conceal

syn  match  treeDirectory   '\%(─\s.*/\)\@<=[^/]*/$'  contains=treeIndicator
syn  match  treeExecutable  '[^/]*\*$'                contains=treeIndicator
syn  match  treeIndicator   '[/*]$'                   conceal

syn  match  treeLinkPrefix  '─\s\zs/.*/\ze[^/]*\s->\s'  conceal
syn  match  treeLink        '[^/]*\s->\s'
"                            ├───┘
"                            └ last path component of a symlink:
"
"                                      /proc/11201/exe -> /usr/lib/firefox/firefox*
"                                                  ^^^^^^^

syn  match  treeLinkFile        '\%(\s->\s\)\@<=.*[^*/]$'
syn  match  treeLinkDirectory   '\%(\s->\s\)\@<=.*/$'  contains=treeIndicator
syn  match  treeLinkExecutable  '\%(\s->\s\)\@<=.*\*$' contains=treeIndicator

" Colors {{{1

hi       treeLink            ctermfg=darkmagenta guifg=darkmagenta
hi link  treeLinkDirectory   Directory
hi link  treeLinkFile        Normal
hi       treeLinkExecutable  ctermfg=darkgreen guifg=darkgreen
hi       treeExecutable      ctermfg=darkgreen guifg=darkgreen
hi link  treeDirectory       Directory
