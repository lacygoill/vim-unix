vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

# Interface {{{1
def unix#trash#list(): string #{{{2
    if !executable('trash-list')
        return CommandUnavailable('trash-list')
    endif

    sil var listing: string = system('trash-list')
    if v:shell_error
        system('')
        return 'echoerr ' .. string('Failed to list the contents of the trash can')
    else
        echo listing
    endif

    return ''
enddef

def unix#trash#put(bang: bool): string #{{{2
    var file: string = expand('%:p')
    if empty(file)
        return ''
    endif

    if !executable('trash-put')
        return CommandUnavailable('trash-put')
    endif

    if !bang
        # First try to unload the buffer.
        # But before that, load the alternate file, if there's one.
        var alternate_file: string = expand('#:p')
        if !empty(alternate_file)
        #   │
        #   └ Why not `filereadable()`?
        #     Because the alternate “file” could be a buffer.
            exe 'e ' .. alternate_file
            bd! %%
        else
            bd!
        endif

        # if it's still loaded, stop
        if bufloaded(file)
            return ''
        endif
    endif

    # now, try to put the file in a trash can
    sil system('trash-put ' .. shellescape(file))
    if v:shell_error
        system('')
        return 'echoerr ' .. string('Failed to delete ' .. file)
    endif

    return bang ? 'e' : ''
enddef

def unix#trash#restore() #{{{2
    !rlwrap trash-restore
enddef
#}}}1
# Utilities {{{1
def CommandUnavailable(cmd: string): string #{{{2
    return 'echoerr '
        .. string(cmd .. ' is not executable; install the trash-cli package')
enddef

