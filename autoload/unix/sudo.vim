vim9script noclear

const ERROR_FILE: string = tempname()

# Interface {{{1
def unix#sudo#edit(arg_file: string, bang: bool) #{{{2
    var file: string = (empty(arg_file) ? expand('%') : arg_file)->fnamemodify(':p')
    unix#sudo#setup(file)

    if !&modified || !empty(arg_file)
        execute 'edit' .. (bang ? '!' : '') .. ' ' .. arg_file
    endif

    if empty(arg_file) || expand('%:p') == arg_file->fnamemodify(':p')
        &readonly = false
    endif
enddef

def unix#sudo#setup(file: string) #{{{2
    if !filereadable(file) && !exists('#BufReadCmd#' .. fnameescape(file))
        execute 'autocmd BufReadCmd ' .. fnameescape(file) .. ' execute SudoReadCmd()'
    endif
    if !filewritable(file) && !exists('#BufWriteCmd#' .. fnameescape(file))
        execute 'autocmd BufReadPost ' .. fnameescape(file) .. ' &readonly = false'
        execute 'autocmd BufWriteCmd ' .. fnameescape(file) .. ' execute SudoWriteCmd()'
    endif
enddef
#}}}1
# Core {{{1
def SilentSudoCmd(editor: string): list<string> #{{{2
    var cmd: string = 'env SUDO_EDITOR=' .. editor .. ' VISUAL=' .. editor .. ' sudo -e'
    if !has('gui_running')
        return ['silent', cmd]

    elseif !empty($SUDO_ASKPASS)
        || filereadable('/etc/sudo.conf')
        && readfile('/etc/sudo.conf', 50)
            ->filter((_, v: string): bool => v =~ '^Path askpass ')
            ->len()
        return ['silent', cmd .. ' -A']

    else
        return ['', cmd]
    endif
enddef

def SudoEditInit() #{{{2
    var files: list<string> = split($SUDO_COMMAND, ' ')[1 : -1]
    if len(files) == argc()
        for i in argc()->range()
            execute 'autocmd BufEnter ' .. argv(i)->fnameescape()
                .. ' if empty(&filetype) || &filetype == "conf"'
                .. ' |     doautocmd filetypedetect BufReadPost ' .. files[i]->fnameescape()
                .. ' | endif'
        endfor
    endif
enddef

if $SUDO_COMMAND =~ '^sudoedit '
    SudoEditInit()
endif

def SudoError(): string #{{{2
    var error: string = readfile(ERROR_FILE)->join(' | ')
    if error =~ '^sudo' || v:shell_error
        system('')
        return strlen(error) != 0 ? error : 'Error invoking sudo'
    else
        return error
    endif
enddef

def SudoReadCmd(): string #{{{2
    silent keepjumps :% delete _
    var silent: string
    var cmd: string
    [silent, cmd] = SilentSudoCmd('cat')
    execute printf('silent read !%s %%:p:S 2>%s', cmd, ERROR_FILE)
    var exit_status: number = v:shell_error
    # reset `v:shell_error`
    system('')
    silent keepjumps :1 delete _
    &l:modified = false
    if exit_status
        return 'echoerr ' .. SudoError()->string()
    endif
    return ''
enddef

def SudoWriteCmd(): string #{{{2
    var silent: string
    var cmd: string
    [silent, cmd] = SilentSudoCmd('tee')
    cmd ..= ' %:p:S >/dev/null'
    cmd ..= ' 2> ' .. ERROR_FILE
    execute silent 'write !' .. cmd
    var error: string = SudoError()
    if !empty(error)
        return 'echoerr ' .. string(error)
    else
        &l:modified = false
        return ''
    endif
enddef

