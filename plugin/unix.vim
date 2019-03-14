if exists('g:loaded_unix')
    finish
endif
let g:loaded_unix = 1

"                                         ┌ if you change the value,
"                                         │ don't forget to put a slash at the end
let s:template_dir = $HOME.'/.vim/template/'

" TODO:
" You shouldn't call `system()`; you should `:echo` it, so that we see the exact
" error message in case of an issue (useful for example with `:Cp`).

" Autocmds "{{{1

augroup my_unix
    au!
    au BufNewFile * call s:maybe_read_template()
                \ | call s:maybe_make_executable()
augroup END

" Commands {{{1

" Do NOT replace `:exe` with `:echoerr`{{{
"
"                                   ┌ ✔
"                                   │
"         com! -bar -nargs=1 Chmod  exe     unix#chmod(<q-args>)
"         com! -bar -nargs=1 Chmod  echoerr unix#chmod(<q-args>)
"                                   │
"                                   └ ✘
"
" Because with `:echoerr`,  if you execute the command from  a function, it will
" raise an error.
"
" MWE:
"
"         com! -bar -nargs=1 Chmod  echoerr unix#chmod(<q-args>)
"         nno  <silent>  cd  :<c-u>call Func()<cr>
"         fu! Func() abort
"             sp
"             e /tmp/file
"             " Error detected while processing function Func:
"             Chmod 123
"         endfu
"
" You could use `:silent!`:
"
"         sil! Chmod 123
"
" But still, you would have to remember  that your command needs it. It can make
" you lose time in needless debugging.
" Besides, you shouldn't bring inconsistency:
" a  default Ex  command doesn't  need `:silent!`  unless it  encounters a  real
" error. Yours should behave in the same way.
" }}}
" FIXME:
" For this reason, should we refactor all our plugins to remove `return 'echoerr
" ...`?

com! -bar -nargs=1  Chmod  exe unix#chmod(<q-args>)

com! -bar -range=% -nargs=? -complete=file  Cloc  call unix#cloc#main(<line1>,<line2>,<q-args>)

com! -bang -bar -nargs=1 -complete=file  Cp  exe unix#cp(<q-args>, <bang>0)

com! -bang -bar -complete=file -nargs=+  Find  call unix#grep('find', <q-args>, <bang>0)
com! -bang -bar -complete=file -nargs=+  Locate  call unix#grep('locate', <q-args>, <bang>0)

com! -bang -bar -nargs=? -complete=dir  Mkdir  call unix#mkdir(<q-args>, <bang>0)

" `:Mv` allows us to move the current file to any location.
" `:Rename` allows us to rename the current file inside the current directory.
com! -bang -bar -nargs=1 -complete=file  Mv  exe unix#move(<q-args>, <bang>0)
"                                         ┌ FIXME: what does it do?
"                                         │
com! -bang -bar -nargs=1 -complete=custom,unix#rename_complete  Rename  Mv<bang> %:h/<args>
"                                                                           └─┤ ├────┘
"                                                   directory of current file ┘ │
"                                                               new chosen name ┘

" Usage:
" Select  some  text, and  execute  `:'<,'>Share`  to  upload the  selection  on
" `0x0.st`, or just execute `:Share` to upload the whole current file.
com! -bar -range=%  Share  call unix#share#main(<line1>, <line2>)

com! -bang -bar -complete=file -nargs=?  SudoEdit  call unix#sudo#edit(<q-args>, <bang>0)
com! -bar  SudoWrite  call unix#sudo#setup(expand('%:p')) | w!

" TODO:
" Are `:SudoWrite` and `:W` doing the same thing?
" Should we eliminate one of them?

" What's the effect of a bang?{{{
"
" `:Tp` deletes the current file and UNLOADS its buffer.
" Also, before  that, it loads  the alternate file if  there's one, so  that the
" current window is not (always) closed.
"
" `:Tp!` deletes the current file and RELOADS the buffer.
" As a result, we can restart the creation of a new file with the same name.
"}}}
com! -bar -bang  Tp  exe unix#trash#put(<bang>0)
com! -bar        Tl  exe unix#trash#list()
"                └ Warning:{{{
"
"                It could conflict with the default `:tl[ast]` command.
"                In practice, I don't think it will, because we'll use `]T` instead.
"}}}

com! -bar -nargs=0 Trr  call unix#trash#restore()

com! -bar Wall  call unix#wall()

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
" > W12: Warning: File "/etc/apt/sources.list" has changed and the buffer was changed in Vim as well
" > See ":help W12" for more info.
" > [O]K, (L)oad File:
"
" If you press `O`, the buffer will be written.
" If you press `L`, the file will be reloaded.
"
" In this particular case, whatever you answer shouldn't matter.
" The file and the buffer contain the same text.
"
" If  you've set  `'autoread'`,  there  should be  no  message,  and Vim  should
" automatically write the buffer.
"}}}
" Why `setl nomod`?{{{
"
" I don't remember what issue it solved, but I keep it because I've noticed that
" it bypasses the W12 warning.
"}}}

"                 ┌ write the buffer on the standard input of a shell command (:h w_c)
"                 │ and execute the latter
"                 │
"                 │   ┌ raise the rights of the `tee` process so that it can write in
"                 │   │ a file owned by any user
"                 ├─┐ │
com! -bar W  exe 'w !sudo tee >/dev/null %' | setl nomod
"                             ├────────┘ └ but write in the current file
"                             │
"                             └ don't write in the terminal

" Mappings {{{1

nno  <silent><unique>  g<c-l>  :<c-u>Cloc<cr>
xno  <silent><unique>  g<c-l>  :Cloc<cr>
nno  <silent><unique>  gl      :<c-u>call unix#cloc#count_lines_in_func()<cr>

" Functions {{{1
fu! s:make_executable() abort "{{{2
    let shebang = matchstr(getline(1), '^#!\S\+')
    if !empty(shebang) && executable('chmod')
        sil call system('chmod +x '.expand('%:p:S'))
        if v:shell_error
            echohl ErrorMsg
            " FIXME:
            " Why is `:unsilent` needed?
            unsilent echom 'Cannot make file executable: '.v:shell_error
            echohl None

            " Why?{{{
            "
            " To reset `v:shell_error` to 0.
            "}}}
            " Is there another way?{{{
            "
            " `v:shell_error` is not writable.
            " So, the only way I can think of is:
            "
            "         :call system('')
            "         :!
            "}}}
            " Is it necessary?{{{
            "
            " I don't know.
            "
            " Usually,  plugins'  authors don't  seem  to  care about  resetting
            " `v:shell_error`:
            "
            "         vim /v:shell_error/gj ~/.vim/**/*.vim ~/.vim/**/vim.snippets ~/.vim/vimrc
            "
            " But, better be safe than sorry.
            "
            " Also, have a look at `:h todo`, and search for `v:shell_error`.
            " A patch was submitted in 2016 to make the variable writable.
            " So, I'm not alone thinking it would  be useful to be able to write
            " this variable.
            "}}}
            call system('')
        endif
    endif
endfu

fu! s:maybe_make_executable() abort "{{{2
    augroup my_make_executable
        au! BufWritePost <buffer>
        au  BufWritePost <buffer> sil! call s:make_executable()
            \ | exe 'au! my_make_executable' | aug! my_make_executable
    augroup END
endfu

fu! s:maybe_read_template() abort "{{{2
    " For an example of template file, have a look at:
    "         /etc/init.d/skeleton

    " Get all the filetypes for which we have a template.
    let filetypes = glob(s:template_dir.'by_filetype/*', 0, 1)
    call map(filetypes, {i,v -> fnamemodify(v, ':t:r')})

    if index(filetypes, &ft) >= 0 && filereadable(s:template_dir.'by_filetype/'.&ft.'.txt')
        "    ┌ don't use the template file as the alternate file for the current window{{{
        "    │ keep the current one
        "    │
        "    │ Note that `:keepalt` is not useful when you read the output of an
        "    │ external command (`:r !cmd`).
        "    │}}}
        exe 'keepalt read '.fnameescape(s:template_dir.'by_filetype/'.&ft.'.txt')
        1d_

    elseif expand('%:p') =~# '.*/compiler/[^/]*\.vim'
    \   && filereadable(s:template_dir.'by_name/compiler.txt')
        call setline(1, ['let current_compiler = '.string(expand('%:p:t:r')), ''])
        exe 'keepalt 2read '.s:template_dir.'by_name/compiler.txt'
        " If our compiler  is in `~/.vim/compiler`, we want to  skip the default
        " compilers in `$VIMRUNTIME/compiler`.
        " In this case, we need 'current_compiler' to be set.

    elseif expand('%:p') =~# '.*/filetype\.vim'
    \   && filereadable(s:template_dir.'by_name/filetype.txt')
        exe 'keepalt read '.s:template_dir.'by_name/filetype.txt'
        1d_

    elseif expand('%:p') =~# '.*/scripts\.vim'
    \   && filereadable(s:template_dir.'by_name/scripts.txt')
        exe 'keepalt read '.s:template_dir.'by_name/scripts.txt'
        1d_

    elseif expand('%:p:h') is# '' . $HOME . '/.zsh/my-completions'
        call setline(1, ['#compdef ' . expand('%:t')[1:], '', ''])
    endif
endfu

