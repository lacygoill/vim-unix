if exists('g:autoloaded_unix#sudo')
    finish
endif
let g:autoloaded_unix#sudo = 1

let s:error_file = tempname()

fu unix#sudo#edit(file, bang) abort "{{{1
    call unix#sudo#setup(fnamemodify(empty(a:file) ? expand('%') : a:file, ':p'))

    if !&modified || !empty(a:file)
        exe 'e'..(a:bang ? '!' : '')..' '..a:file
    endif

    if empty(a:file) || expand('%:p') is# fnamemodify(a:file, ':p')
        set noreadonly
    endif
endfu

fu unix#sudo#setup(file) abort "{{{1
    if !filereadable(a:file) && !exists('#BufReadCmd#'..fnameescape(a:file))
        exe 'au BufReadCmd '..fnameescape(a:file)..' exe s:sudo_read_cmd()'
    endif
    if !filewritable(a:file) && !exists('#BufWriteCmd#'..fnameescape(a:file))
        exe 'au BufReadPost '..fnameescape(a:file)..' set noreadonly'
        exe 'au BufWriteCmd '..fnameescape(a:file)..' exe s:sudo_write_cmd()'
    endif
endfu

fu s:silent_sudo_cmd(editor) abort "{{{1
    let cmd = 'env SUDO_EDITOR='..a:editor..' VISUAL='..a:editor..' sudo -e'
    let local_nvim = has('nvim') && len($DISPLAY..$SECURITYSESSIONID)
    if !has('gui_running') && !local_nvim
        return ['silent', cmd]

    elseif !empty($SUDO_ASKPASS)
    \ ||   filereadable('/etc/sudo.conf')
    \ &&   len(filter(readfile('/etc/sudo.conf', 50), {_,v -> v =~# '^Path askpass '}))
        return ['silent', cmd..' -A']

    else
        return [local_nvim ? 'silent' : '', cmd]
    endif
endfu

fu s:sudo_edit_init() abort "{{{1
    let files = split($SUDO_COMMAND, ' ')[1:-1]
    if len(files) == argc()
        for i in range(argc())
            exe 'autocmd BufEnter '..fnameescape(argv(i))
                        \ 'if empty(&ft) || &ft is "conf"'
                        \ '|do filetypedetect BufReadPost '..fnameescape(files[i])
                        \ '|endif'
        endfor
    endif
endfu

if $SUDO_COMMAND =~# '^sudoedit '
    call s:sudo_edit_init()
endif

fu s:sudo_error() abort "{{{1
    let error = join(readfile(s:error_file), ' | ')
    if error =~# '^sudo' || v:shell_error
        call system('')
        return len(error) ? error : 'Error invoking sudo'
    else
        return error
    endif
endfu

fu s:sudo_read_cmd() abort "{{{1
    sil %d_
    let [silent, cmd] = s:silent_sudo_cmd('cat')
    sil exe printf('read !%s %%:p:S 2>%s', cmd, s:error_file)
    let exit_status = v:shell_error
    " reset `v:shell_error`
    call system('')
    sil 1d_
    setl nomodified
    if exit_status
        return 'echoerr '..string(s:sudo_error())
    endif
endfu

fu s:sudo_write_cmd() abort "{{{1
    let [silent, cmd] = s:silent_sudo_cmd('tee')
    let cmd ..= ' %:p:S >/dev/null'
    let cmd ..= ' 2> '..s:error_file
    exe silent 'write !'..cmd
    let error = s:sudo_error()
    if !empty(error)
        return 'echoerr '..string(error)
    else
        setl nomodified
        return ''
    endif
endfu

