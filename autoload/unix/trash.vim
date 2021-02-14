vim9script noclear

if exists('loaded') | finish | endif
var loaded = true

# Interface {{{1
def unix#trash#list() #{{{2
    if !executable('trash-list')
        Error('trash-list is not executable; install the trash-cli package')
        return
    endif

    sil var listing: string = system('trash-list')
    if v:shell_error
        system('')
        Error('Failed to list the contents of the trash can')
        return
    else
        echo listing
    endif
enddef

def unix#trash#put(bang: bool) #{{{2
    var file: string = expand('%:p')
    if empty(file)
        return
    endif

    if !executable('trash-put')
        Error('trash-put is not executable; install the trash-cli package')
        return
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
            return
        endif
    endif

    # now, try to put the file in a trash can
    sil system('trash-put ' .. shellescape(file))
    if v:shell_error
        system('')
        Error('Failed to delete ' .. file)
        return
    endif

    if bang
        e
    endif
enddef

def unix#trash#restore() #{{{2
    !rlwrap trash-restore
enddef
#}}}1
# Utilities {{{1
def Error(msg: string) #{{{2
    echohl ErrorMsg
    echom msg
    echohl NONE
enddef

