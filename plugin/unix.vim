if exists('g:loaded_unix')
    finish
endif
let g:loaded_unix = 1

" TODO:
" implement a `:Cp` command to create a copy of a file

" TODO:
" When you remove/delete a  file, it would be nice to  get the alternate buffer,
" instead of closing the window.
" Btw, didn't the original plugin already do that?
" Did we break this feature?

let s:error_file = tempname()
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
com! -bar -nargs=1 Chmod  exe s:chmod(<q-args>)
com! -bar          Delete exe s:delete()
com! -bar          Unlink exe s:unlink()

com!      -bang -complete=file -nargs=+ Find   call s:grep('find',   <q-args>, <bang>0)
com!      -bang -complete=file -nargs=+ Locate call s:grep('locate', <q-args>, <bang>0)

com!      -bang -nargs=? -complete=dir Mkdir call s:mkdir(<q-args>, <bang>0)

" `:Move` allows us to move the current file to any location.
" `:Rename` allows us to rename the current file inside the current directory.
com!      -nargs=1 -bang -complete=file                     Move    exe s:move(<q-args>, <bang>0)
com!      -nargs=1 -bang -complete=custom,s:rename_complete Rename  Move<bang> %:h/<args>
"                                                                              └─┤ ├────┘
"                                                     directory of current file ─┘ │
"                                                               new chosen name ───┘

com!      -bang -complete=file -nargs=? SudoEdit  call s:sudo_edit(<q-args>, <bang>0)
com! -bar                               SudoWrite call s:sudo_setup(expand('%:p')) | w!

com! -bar Wall call s:wall()


"                  ┌ write the buffer on the standard input of a shell command (:h w_c)
"                  │ and execute the latter
"                ┌─┤
"                │ │ ┌─ raise the right of the `tee` process so that it can write in
"                │ │ │  a file owned by any user
"                │ │ │
com! -bar W exe 'w !sudo tee >/dev/null %' | setl nomod
"                            │        │ └─ but write in the current file
"                            └────────┤
"                                     └ don't write in the terminal

" La commande qui précède a pour but de nous permettre d'écrire dans un{{{
" fichier sur lesquels nos droits sont insuffisants car on n'a pas lancé Vim
" en root ou avec sudo.

" NOTE:
" Qd on utilise `:W` on a le message d'avertissement W12 (:h W12) semblable
" au message d'avertissement W11 (on peut répondre automatiquement à la question
" posée par W11 en activant l'option autoread).
"
" W12 nous laisse le choix entre 2 propositions:
"
"         • écrire le buffer modifié dans le fichier (Load)
"         • relire le fichier pour écraser le buffer (OK)
"
" Il faut répondre "Load" sous peine de ne pas voir ses changements sauvegardés
" dans le fichier.
"}}}

" Functions {{{1
fu! s:chmod(flags) abort "{{{2
    let output = systemlist('chmod '.a:flags.' '.shellescape(expand('%:p')))

    " reload buffer to avoid a (delayed) message such as:
    "         “"/tmp/file" 1L, 6C“
    e

    return !empty(output) ? 'echoerr '.string(output[0]) : ''

    " Alternative:
    "
    "     if !empty(output)
    "         'echoerr '.string(output[0])
    "     else
    "         call timer_start(0, {-> execute('redraw!', '')})
    "         return ''
    "     endif
    "
    " This code erases the command when it succeeds.
    " You  need the  bang after  `:redraw`, and  it seems  that it  needs to  be
    " executed non silently.
endfu

fu! s:delete() abort "{{{2
    let file = expand('%:p')
    if empty(file)
        return ''
    endif

    " first try to unload the buffer
    bd!
    " if it's still loaded, stop
    if bufloaded(file)
        return ''
    endif

    " now, try to put the file in a trash can
    sil exe '!trash-put '.file
    redraw!
    if v:shell_error
        return 'echoerr '.string('Failed to delete '.file)
    endif

    return ''
endfu

fu! s:grep(prg, pat, bang) abort "{{{2
    let grepprg    = &l:grepprg
    let grepformat = &l:grepformat
    let shellpipe  = &shellpipe

    try
        let &l:grepprg = a:prg
        "                ┌─ the output of `$grep` will just contain file names
        "                │
        setl grepformat=%f
        " The default value of 'sp' ('2>&1| tee') causes the error messages
        " (ex: “permission denied“) to be included in the output of `:grep`.
        " It's noise, so we get rid of them by temporarily tweaking 'sp'.
        let &shellpipe = '| tee'
        " FIXME:
        " Don't use `:grep`, it makes the screen flash. Use `cgetexpr` instead.
        " Look at what we did in `myfuncs#op_grep()`.

        "            ┌─ don't jump to first match, we want to decide ourselves
        "            │  whether to jump
        "            │
        sil exe 'grep! '.a:pat
        " │
        " └─ bypass prompt “Press ENTER or type command to continue“
        redraw!

        " No need to inform  our custom autocmds, responsible for dealing with
        " qf windows (opening, layout, …), that we have just populated a qfl:
        "
        "         doautocmd <nomodeline> QuickFixCmdPost grep
        "
        " … because `:vimgrep` has already triggered `QuickFixCmdPost`.

        if !empty(getqflist())
            call setqflist([], 'a', { 'title': '$ '.a:prg.' '.a:pat })

            if &bt is# 'quickfix'
                call qf#set_matches('eunuch:grep', 'Conceal', 'double_bar')
                call qf#create_matches()
            endif

            " If we didn't use a bang when we executed `:Locate` or `:Find`, and
            " the command found sth, jump to the first match.
            " We give to a bang the same meaning as Vim does with `:grep` or `:make`.
            if !a:bang
                cfirst
            endif
        endif
    catch
        return lg#catch_error()
    finally
        let &l:grepprg    = grepprg
        let &l:grepformat = grepformat
        let &shellpipe    = shellpipe
    endtry
endfu

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

    " Get all the filetypes for which we have a template in `~/.vim/template/`.
    let filetypes = glob($HOME.'/.vim/template/*', 0, 1)
    call filter(filetypes, {i,v -> v !~# 'compiler.vim'})
    call map(filetypes, {i,v -> fnamemodify(v, ':t:r')})

    if index(filetypes, &ft) >= 0 && filereadable($HOME.'/.vim/template/'.&ft.'.vim')
        "    ┌─ don't use the template file as the alternate file for the current
        "    │  window; keep the current one
        "    │
        "    │  NOTE:
        "    │  `:keepalt` is not useful when you read the output of an external
        "    │  command (:r !cmd)
        "    │
        exe 'keepalt read '.fnameescape($HOME.'/.vim/template/'.&ft.'.vim')
        1d_

    elseif expand('%:p') =~# '.*/compiler/[^/]*.vim'
    \   && filereadable($HOME.'/.vim/template/compiler.vim')
        keepalt read $HOME/.vim/template/compiler.vim
        " If  our  compiler  is  in  `~/.vim/compiler`,  we  want  to  skip  the
        " default  compilers in  `$VIMRUNTIME/compiler`. In this  case, we  need
        " 'current_compiler' to be set.
        0put ='let current_compiler = '.string(expand('%:p:t:r'))
    endif
endfu

fu! s:mkdir(dir, bang) abort "{{{2
    let dest = empty(a:dir)
    \?             expand('%:p:h')
    \:         a:dir[0] is# '/'
    \?             a:dir
    \:             expand('%:p').a:dir

    try
        call mkdir(dest, a:bang ? 'p' : '')
    catch
        return lg#catch_error()
    endtry
endfu

fu! s:move(dst, bang) abort "{{{2
    let src = expand('%:p')
    let dst = fnamemodify(a:dst, ':p')

    " If the destination is a directory, it must be completed, by appending
    " the current filename.

    "                 ┌────────────────────── the destination is an existing directory
    "                 │                     ┌ or a future directory (we're going to create it)
    "  ┌──────────────┤    ┌────────────────┤
    if isdirectory(dst) || dst[-1:-1] is# '/'
        "                                        ┌ make sure there's a slash
        "                                        │ between the directory and the filename
        "          ┌─────────────────────────────┤
        let dst .= (dst[-1:-1] is# '/' ? '' : '/').fnamemodify(src, ':t')
        "                                          └────────────────────┤
        "                                                               └ add the current filename
        "                                                                 to complete the destination
    endif

    " If the directory of the destination doesn't exist, create it.
    if !isdirectory(fnamemodify(dst, ':h'))
        call mkdir(fnamemodify(dst, ':h'), 'p')
    endif

    let dst = substitute(simplify(dst), '^\.\/', '', '')

    " `:Move` and `:Rename` should behave like `:saveas`.
    "
    "         :Move existing_file      ✘
    "         :Rename existing_file    ✘
    "         :saveas existing_file    ✘
    "
    " The operation shouldn't overwrite the file.
    " Except if we added a bang:
    "
    "         :Move! existing_file     ✔
    "         :Rename! existing_file   ✔
    "         :saveas! existing_file   ✔

    " The destination is occupied by an existing file, and no bang was added.
    " The command must fail.
    if filereadable(dst) && !a:bang
        return 'keepalt saveas '.fnameescape(dst)
        "       │
        "       └─ even though `:saveas` is going to fail, it will still
        "          change the alternate file for the current window (`dst`);
        "          we don't want that

    " Try to rename current file.
    " What are the differences between `:saveas` and `rename()`:
    "
    "       `rename()` gets rid of the old file, after the renaming; `:saveas` does NOT
    "       `rename()` can move a file to a different filesystem; `:saveas` ?
    elseif rename(src, dst)
        " If a problem occurred, inform us.
        return 'echoerr '.string('Failed to rename '.string(src).' to '.string(dst))
    else
        " If no pb occurred execute `:saveas! dst`.
        "
        " FIXME:
        " Why set the buffer as modified?
        setl modified
        " FIXME:
        " Why this command? Maybe to trigger one (some?, all?) of those events:
        "
        "         BufNew
        "         BufFilePre
        "         BufFilePost
        "         BufAdd
        "         BufCreate
        "         BufWrite
        "         BufWritePre
        "         BufWritePost
        exe 'keepalt saveas! '.fnameescape(dst)

        " Get rid of old buffer (it's not linked to a file anymore).
        " But only if it's not the current one.
        " It could be the current one if we execute, by accident:
        "
        "         :Move   /path/to/current/file
        "         :Rename current_filename
        if src isnot# expand('%:p')
            exe 'bw '.fnameescape(src)
        endif

        " detect the filetype to get syntax highlighting and load ftplugins
        filetype detect
        return ''
    endif
endfu

fu! s:rename_complete(arglead, _c, _p) abort "{{{2
    let prefix = expand('%:p:h').'/'
    let files  = glob(prefix.a:arglead.'*', 0, 1)
    call filter(files, { i,v -> simplify(v) isnot# simplify(expand('%:p')) })
    call map(files, { i,v ->   v[strlen(prefix) : -1]
    \                        . (isdirectory(v) ? '/' : '') })

    " Why not filtering the files?{{{
    "
    " We don't need to, because the command invoking this completion function is
    " defined with the attribute `-complete=custom`, not `-complete=customlist`,
    " which means Vim performs a basic filtering automatically:
    "
    "     • each file must begin with `a:arglead`
    "     • the comparison respects 'ic' and 'scs'
    " }}}
    return join(files + ['../'], "\n")
endfu

fu! s:should_write_buffer(seen) abort "{{{2
    " 'buftype' is a buffer-local option, whose value determines the type of
    " buffer. We want to write a buffer currently displayed in a window, iff:
    "
    "         • it is a regular buffer (&bt = '')
    "
    "         • an autocmd listening to `BufWriteCmd` determines how it must be written
    "           (&bt = 'acwrite')

    if !&readonly
  \&&  &modifiable
  \&&  &bt is# '' || &bt is# 'acwrite'
  \&&  !empty(expand('%'))
  \&&  !has_key(a:seen, bufnr('%'))
        return 1
    endif
endfu

fu! s:silent_sudo_cmd(editor) abort "{{{2
    let cmd = 'env SUDO_EDITOR='.a:editor.' VISUAL='.a:editor.' sudo -e'
    let local_nvim = has('nvim') && len($DISPLAY . $SECURITYSESSIONID)
    if !has('gui_running') && !local_nvim
        return ['silent', cmd]

    elseif !empty($SUDO_ASKPASS)
    \||           filereadable('/etc/sudo.conf')
    \&&           len(filter(readfile('/etc/sudo.conf', 50), { i,v -> v =~# '^Path askpass ' }))
        return ['silent', cmd.' -A']

    else
        return [local_nvim ? 'silent' : '', cmd]
    endif
endfu

fu! s:sudo_edit(file, bang) abort "{{{2
    call s:sudo_setup(fnamemodify(empty(a:file) ? expand('%') : a:file, ':p'))

    if !&modified || !empty(a:file)
        exe 'e'.(a:bang ? '!' : '').' '.a:file
    endif

    if empty(a:file) || expand('%:p') is# fnamemodify(a:file, ':p')
        set noreadonly
    endif
endfu

fu! s:sudo_edit_init() abort "{{{2
    let files = split($SUDO_COMMAND, ' ')[1:-1]
    if len(files) ==# argc()
        for i in range(argc())
            exe 'autocmd BufEnter '.fnameescape(argv(i))
                        \ 'if empty(&ft) || &ft is "conf"'
                        \ '|doautocmd <nomodeline> filetypedetect BufReadPost '.fnameescape(files[i])
                        \ '|endif'
        endfor
    endif
endfu

if $SUDO_COMMAND =~# '^sudoedit '
    call s:sudo_edit_init()
endif

fu! s:sudo_error() abort "{{{2
    let error = join(readfile(s:error_file), ' | ')
    if error =~# '^sudo' || v:shell_error
        return len(error) ? error : 'Error invoking sudo'
    else
        return error
    endif
endfu

fu! s:sudo_read_cmd() abort "{{{2
    sil %d_
    let [silent, cmd] = s:silent_sudo_cmd('cat')
    exe sil 'read !'.cmd.' "%" 2> '.s:error_file
    let exit_status = v:shell_error
    sil 1d_
    setl nomodified
    if exit_status
        return 'echoerr '.string(s:sudo_error())
    endif
endfu

fu! s:sudo_setup(file) abort "{{{2
    if !filereadable(a:file) && !exists('#BufReadCmd#'.fnameescape(a:file))
        exe 'au BufReadCmd '.fnameescape(a:file).' exe s:sudo_read_cmd()'
    endif
    if !filewritable(a:file) && !exists('#BufWriteCmd#'.fnameescape(a:file))
        exe 'au BufReadPost '.fnameescape(a:file).' set noreadonly'
        exe 'au BufWriteCmd '.fnameescape(a:file).' exe s:sudo_write_cmd()'
    endif
endfu

fu! s:sudo_write_cmd() abort "{{{2
    let [silent, cmd] = s:silent_sudo_cmd('tee')
    let cmd .= ' "%" >/dev/null'
    let cmd .= ' 2> '.s:error_file
    exe silent 'write !'.cmd
    let error = s:sudo_error()
    if !empty(error)
        return 'echoerr '.string(error)
    else
        setl nomodified
        return ''
    endif
endfu

fu! s:unlink() abort "{{{2
    if &modified
        return 'e'
    else

        let file = expand('%:p')
        sil exe '!trash-put '.file
        redraw!
        if v:shell_error
            return 'echoerr '.string('Failed to delete '.file)
        else
            " we've deleted the current file, so now, we reload the buffer
            return "e!"
            "        │
            "        └─ needed if the buffer is modified
        endif
    endif
endfu

fu! s:wall() abort "{{{2
    let cur_winid = win_getid()
    let seen = {}
    if !&readonly && !empty(expand('%'))
        let seen[bufnr('%')] = 1
        write
    endif
    sil! tabdo windo if s:should_write_buffer(seen)
                  \|     write
                  \|     let seen[bufnr('%')] = 1
                  \| endif
    call win_gotoid(cur_winid)
endfu
