if exists('g:autoloaded_unix')
    finish
endif
let g:autoloaded_unix = 1

let s:error_file = tempname()

fu! unix#chmod(flags) abort "{{{1
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

fu! unix#delete() abort "{{{1
    if !executable('trash-put')
        return 'echoerr '.string('trash-put is not executable; install the trash-cli package')
    endif

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

fu! unix#grep(prg, pat, bang) abort "{{{1
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

fu! unix#mkdir(dir, bang) abort "{{{1
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

fu! unix#move(dst, bang) abort "{{{1
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

fu! unix#rename_complete(arglead, _c, _p) abort "{{{1
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

fu! s:should_write_buffer(seen) abort "{{{1
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

fu! unix#sudo_edit(file, bang) abort "{{{2
    call unix#sudo_setup(fnamemodify(empty(a:file) ? expand('%') : a:file, ':p'))

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

fu! unix#sudo_setup(file) abort "{{{2
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

fu! unix#unlink() abort "{{{1
    if !executable('trash-put')
        return 'echoerr '.string('trash-put is not executable; install the trash-cli package')
    endif

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

fu! unix#wall() abort "{{{1
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
