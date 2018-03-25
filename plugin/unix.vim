if exists('g:loaded_unix')
    finish
endif
let g:loaded_unix = 1

" TODO:
" implement a `:Cp` command to create a copy of a file

" TODO:
" When you delete a file, it would  be nice to get the alternate buffer, instead
" of closing the window.


let s:template_dir = $HOME.'/.vim/template'

" Autocmds "{{{1

augroup my_unix
    au!
    au BufNewFile * call s:maybe_read_template()
                 \| call s:maybe_make_executable()
augroup END

" Commands {{{1

" Do NOT replace some `exe`'s with `:echoerr`.
" If you want to use a command inside a function, it will raise an error.
"
" Yeah I know:     silent!
" But still, you  have to remember that  your command needs it. It  can make you
" lose time in needless debugging.
" Don't bring inconsistency, a default Ex command doesn't need `:silent!` unless
" it encounters a real error. Ours should behave in the same way.
com! -bar -nargs=1 Chmod  exe unix#chmod(<q-args>)
com! -bar          Delete exe unix#delete()
com! -bar          Unlink exe unix#unlink()

com!      -bang -complete=file -nargs=+ Find   call unix#grep('find',   <q-args>, <bang>0)
com!      -bang -complete=file -nargs=+ Locate call unix#grep('locate', <q-args>, <bang>0)

com!      -bang -nargs=? -complete=dir Mkdir call unix#mkdir(<q-args>, <bang>0)

" `:Move` allows us to move the current file to any location.
" `:Rename` allows us to rename the current file inside the current directory.
com!      -nargs=1 -bang -complete=file                        Move    exe unix#move(<q-args>, <bang>0)
com!      -nargs=1 -bang -complete=custom,unix#rename_complete Rename  Move<bang> %:h/<args>
"                                                                                 └─┤ ├────┘
"                                                        directory of current file ─┘ │
"                                                                  new chosen name ───┘

com!      -bang -complete=file -nargs=? SudoEdit  call unix#sudo_edit(<q-args>, <bang>0)
com! -bar                               SudoWrite call unix#sudo_setup(expand('%:p')) | w!

com! -bar Wall call unix#wall()

" What's the purpose of `:W`?{{{
"
" It allows us to write a file for which we don't have write access to.
" This happens when we  try to edit a root file in a  Vim session started from a
" regular user.
"}}}
" What to do if I have the message `W11` or `W12`?{{{
"
" The full message looks something like this:
"
"         W11: Warning: File "/tmp/file" has changed since editing started
"         See ":help W11" for more info.
"         [O]K, (L)oad File:
"
" If you press `O`, the buffer will be written.
" If you press `L`, the file will be reloaded.
"
" In this particular case, whatever you answer shouldn't matter.
" The file and the buffer contain the same text.
"
" If  you've  set  'autoread',  there  should be  no  message,  and  Vim  should
" automatically write the buffer.
"}}}

"                  ┌ write the buffer on the standard input of a shell command (:h w_c)
"                  │ and execute the latter
"                ┌─┤
"                │ │ ┌ raise the right of the `tee` process so that it can write in
"                │ │ │ a file owned by any user
"                │ │ │
com! -bar W exe 'w !sudo tee >/dev/null %' | setl nomod
"                            │        │ └─ but write in the current file
"                            └────────┤
"                                     └ don't write in the terminal

" Functions {{{1
fu! s:make_executable() abort "{{{2
    let shebang = matchstr(getline(1), '^#!\S\+')
    if !empty(shebang) && executable('chmod')
        call system('chmod +x '.shellescape(expand('%:p')))
        if v:shell_error
            echohl ErrorMsg
            echom 'Cannot make file executable: '.v:shell_error
            echohl None
        endif
    endif
endfu

fu! s:maybe_make_executable() abort "{{{2
    augroup my_make_executable
        au! BufWritePost <buffer>
        au  BufWritePost <buffer> call s:make_executable()
                               \| exe 'au! my_make_executable'
                               \| aug! my_make_executable
    augroup END
endfu

fu! s:maybe_read_template() abort "{{{2
    " For an example of template file, have a look at:
    "         /etc/init.d/skeleton

    " Get all the filetypes for which we have a template.
    let filetypes = glob(s:template_dir.'/*', 0, 1)
    call filter(filetypes, {i,v -> v !~# 'compiler.vim'})
    call map(filetypes, {i,v -> fnamemodify(v, ':t:r')})

    if index(filetypes, &ft) >= 0 && filereadable(s:template_dir.'/'.&ft.'.vim')
        "    ┌─ don't use the template file as the alternate file for the current
        "    │  window; keep the current one
        "    │
        "    │  Note that, `:keepalt` is not useful  when you read the output of
        "    │  an external command (:r !cmd)
        "    │
        exe 'keepalt read '.fnameescape(s:template_dir.'/'.&ft.'.vim')
        1d_

    elseif expand('%:p') =~# '.*/compiler/[^/]*.vim'
    \   && filereadable(s:template_dir.'/compiler.vim')
        exe 'keepalt read '.s:template_dir.'/compiler.vim'
        " If  our  compiler  is  in  `~/.vim/compiler`,  we  want  to  skip  the
        " default  compilers in  `$VIMRUNTIME/compiler`. In this  case, we  need
        " 'current_compiler' to be set.
        0put ='let current_compiler = '.string(expand('%:p:t:r'))
    endif
endfu

