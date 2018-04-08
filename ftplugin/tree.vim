let b:did_ftplugin = 1

setl bh=wipe bt=nofile nobl noswf nowrap

augroup my_tree
    au! * <buffer>
    au BufWinEnter <buffer> setl cocu=nc cole=3
    \                            fde=unix#tree#fde() fdl=99 fdm=expr fdt=unix#tree#fdt()
augroup END

nno  <buffer><nowait><silent>  q   :<c-u>close<cr>

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                          setl bh< bl< bt< cocu< cole< fde< fdl< fdm< fdt< swf< wrap<
\                        | exe 'au! my_tree * <buffer>'
\                        | exe 'nunmap <buffer> q'
\                      "

