fu unix#trash#list() abort "{{{1
    if !executable('trash-list')
        return s:command_unavailable('trash-list')
    endif

    sil let listing = system('trash-list')
    if v:shell_error
        call system('')
        return 'echoerr '.string('Failed to list the contents of the trash can')
    else
        echo listing
    endif

    return ''
endfu

fu unix#trash#put(bang) abort "{{{1
    let file = expand('%:p')
    if empty(file)
        return ''
    endif

    if !executable('trash-put')
        return s:command_unavailable('trash-put')
    endif

    if !a:bang
        " First try to unload the buffer.
        " But before that, load the alternate file, if there's one.
        let alternate_file = expand('#:p')
        if !empty(alternate_file)
        "   │
        "   └ Why not `filereadable()`?
        "     Because the alternate “file” could be a buffer.
            exe 'e '.alternate_file
            bd! #
        else
            bd!
        endif

        " if it's still loaded, stop
        if bufloaded(file)
            return ''
        endif
    endif

    " now, try to put the file in a trash can
    sil call system('trash-put '.shellescape(file))
    if v:shell_error
        call system('')
        return 'echoerr '.string('Failed to delete '.file)
    endif

    return a:bang ? 'e' : ''
endfu

fu unix#trash#restore() abort "{{{1
    " `:!` can't be interactive in Neovim
    " See: https://github.com/neovim/neovim/issues/1496
    if !has('nvim')
        !rlwrap restore-trash
    else
        new
        let id = termopen('/bin/zsh')
        call chansend(id, ['rlwrap restore-trash', ''])
        startinsert
    endif
endfu

