vim9script noclear

# Interface {{{1
def unix#trash#list() #{{{2
    if !executable('trash-list')
        Error('trash-list is not executable; install the trash-cli package')
        return
    endif

    silent var listing: string = system('trash-list')
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
            execute 'edit ' .. alternate_file
            bdelete! %%
        else
            bdelete!
        endif

        # if it's still loaded, stop
        if bufloaded(file)
            return
        endif
    endif

    # now, try to put the file in a trash can
    silent system('trash-put ' .. shellescape(file))
    if v:shell_error
        system('')
        Error('Failed to delete ' .. file)
        return
    endif

    if bang
        edit
    endif
enddef

def unix#trash#restore() #{{{2
    # Simpler alternative:{{{
    #
    #     :terminal /bin/sh -c "sleep .1 && rlwrap trash-restore"
    #
    # The `sleep(1)` might be necessary  to avoid the listing of `trash-restore`
    # to be slightly messed up.
    #}}}
    var buf: number = terminal#togglePopup#main()
    term_sendkeys(buf, "rlwrap trash-restore\<CR>")
enddef
#}}}1
# Utilities {{{1
def Error(msg: string) #{{{2
    echohl ErrorMsg
    echomsg msg
    echohl NONE
enddef

