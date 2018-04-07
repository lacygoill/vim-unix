let b:did_ftplugin = 1

setl bh=wipe bt=nofile nobl noswf nowrap

augroup my_tree
    au! * <buffer>
    au BufWinEnter <buffer> setl cole=3 cocu=nc
augroup END

nno  <buffer><nowait><silent>  gf  :<c-u>echo 'press Zf instead'<cr>
nno  <buffer><nowait><silent>  q   :<c-u>close<cr>

" teardown {{{1

let b:undo_ftplugin =         get(b:, 'undo_ftplugin', '')
\                     .(empty(get(b:, 'undo_ftplugin', '')) ? '' : '|')
\                     ."
\                          setl bh< bl< bt< cocu< cole< swf< wrap<
\                        | exe 'au! my_tree * <buffer>'
\                        | exe 'nunmap <buffer> gf'
\                        | exe 'nunmap <buffer> q'
\                      "

