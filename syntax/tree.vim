let b:current_syntax = 'tree'

" Syntax {{{1

syn  match  treeOnlyLastComponent  '─\s\zs.*/\%(.\{-}[^/]\)\@='  conceal

syn  match  treeDirectory   '\%(─\s.*/\)\@<=[^/]*/$'
syn  match  treeExecutable  '[^/]*\*$'

syn  match  treeLinkPrefix  '─\s\zs/.*/\ze[^/]*\s->\s'  conceal
syn  match  treeLink        '[^/]*\s->\s'
"                            ├───┘
"                            └ last path component of a symlink:
"
"                                      /proc/11201/exe -> /usr/lib/firefox/firefox*
"                                                  ^^^^^^^

syn  match  treeLinkFile        '\%(\s->\s\)\@<=.*[^*/]$'
syn  match  treeLinkDirectory   '\%(\s->\s\)\@<=.*/$'
syn  match  treeLinkExecutable  '\%(\s->\s\)\@<=.*\*$'

syn  match  treeWarning  '[^/]*/\=\ze\s\[.\{-}\]'

" Colors {{{1

hi link  treeWarning         WarningMsg
hi link  treeDirectory       Directory
hi       treeExecutable      ctermfg=darkgreen guifg=darkgreen

hi       treeLink            ctermfg=darkmagenta guifg=darkmagenta
hi link  treeLinkFile        Normal
hi link  treeLinkDirectory   Directory
hi       treeLinkExecutable  ctermfg=darkgreen guifg=darkgreen
