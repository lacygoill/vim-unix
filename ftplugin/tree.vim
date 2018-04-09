let b:did_ftplugin = 1

setl bt=nofile nobl noswf nowrap

augroup my_tree
    au! * <buffer>
    au BufWinEnter <buffer> setl cocu=nc cole=3
    \                            fde=unix#tree#fde() fdl=99 fdm=expr fdt=unix#tree#fdt()
augroup END

nno  <buffer><nowait><silent>  <c-n>  :<c-u>call search('.*/$')<cr>
nno  <buffer><nowait><silent>  <c-p>  :<c-u>call search('.*/$', 'b')<cr>

nno  <buffer><nowait><silent>  h  :<c-u>call unix#tree#relative_dir('parent')<cr>
nno  <buffer><nowait><silent>  l  :<c-u>call unix#tree#relative_dir('child')<cr>

nno  <buffer><nowait><silent>  q    :<c-u>call unix#tree#close()<cr>
nno  <buffer><nowait><silent>  R    :<c-u>call unix#tree#reload()<cr>
nno  <buffer><nowait><silent>  Zf   :<c-u>call unix#tree#open('split')<cr>
nno  <buffer><nowait><silent>  Zgf  :<c-u>call unix#tree#open('tab')<cr>

nno  <buffer><nowait><silent>  gh  :<c-u>call unix#tree#hide_dot_entries()<cr>

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                          setl bl< bt< cocu< cole< fde< fdl< fdm< fdt< swf< wrap<
\                        | exe 'au! my_tree * <buffer>'
\                        | exe 'nunmap <buffer> h'
\                        | exe 'nunmap <buffer> l'
\                        | exe 'nunmap <buffer> q'
\                        | exe 'nunmap <buffer> R'
\                        | exe 'nunmap <buffer> Zf'
\                        | exe 'nunmap <buffer> Zgf'
\                        | exe 'nunmap <buffer> gh'
\                        | exe 'nunmap <buffer> <c-n>'
\                        | exe 'nunmap <buffer> <c-p>'
\                      "

