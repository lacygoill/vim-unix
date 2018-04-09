let b:did_ftplugin = 1

setl bh=wipe bt=nofile nobl noswf nowrap

augroup my_tree
    au! * <buffer>
    au BufWinEnter <buffer> setl cocu=nc cole=3
    \                            fde=unix#tree#fde() fdl=99 fdm=expr fdt=unix#tree#fdt()
augroup END

nno  <buffer><nowait><silent>  <c-n>  :<c-u>call search('.*/$')<cr>
nno  <buffer><nowait><silent>  <c-p>  :<c-u>call search('.*/$', 'b')<cr>

nno  <buffer><nowait><silent>  q    :<c-u>call unix#tree#close()<cr>
nno  <buffer><nowait><silent>  Zf   :<c-u>call unix#tree#open('split')<cr>
nno  <buffer><nowait><silent>  Zgf  :<c-u>call unix#tree#open('tab')<cr>

nno  <buffer><nowait><silent>  <c-h>  :<c-u>call unix#tree#relative_dir('parent')<cr>
nno  <buffer><nowait><silent>  <c-m>  :<c-u>call unix#tree#relative_dir('child')<cr>

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                          setl bh< bl< bt< cocu< cole< fde< fdl< fdm< fdt< swf< wrap<
\                        | exe 'au! my_tree * <buffer>'
\                        | exe 'nunmap <buffer> q'
\                        | exe 'nunmap <buffer> Zf'
\                        | exe 'nunmap <buffer> Zgf'
\                        | exe 'nunmap <buffer> <c-n>'
\                        | exe 'nunmap <buffer> <c-p>'
\                        | exe 'nunmap <buffer> <c-h>'
\                        | exe 'nunmap <buffer> <c-m>'
\                      "

