vim9script noclear

import Catch from 'lg.vim'

def unix#chmod(flags: string) #{{{1
    # TODO: Use `setfperm()` instead, and look at how tpope implemented this function.
    silent var output: list<string> = systemlist('chmod ' .. flags .. ' ' .. expand('%:p:S'))

    # reload buffer to avoid a (delayed) message such as: "/tmp/file 1L, 6C"
    edit

    if !empty(output)
        output[0]->Error()
    endif

    # Alternative:
    #
    #     if !empty(output)
    #         'echoerr ' .. string(output[0])
    #     else
    #         call timer_start(0, {-> execute('redraw!', '')})
    #         return ''
    #     endif
    #
    # This code erases the command when it succeeds.
    # You  need the  bang after  `:redraw`, and  it seems  that it  needs to  be
    # executed non silently.
enddef

def unix#cp(arg_dst: string, bang: bool) #{{{1
    var src: string = expand('%:p')
    var dir: string = expand('%:p:h')
    var dst: string = stridx(arg_dst, '/') == 0
        ?     arg_dst
        :     dir .. '/' .. simplify(arg_dst)

    if filereadable(dst) && !bang
        Error(string(dst) .. ' already exists; add a bang to overwrite it')
        return
    endif
    silent system('cp'
        # follow symbolic links
        .. ' -L'
        # do not overwrite an existing file
        .. (bang ? '' : 'n')
        # same as --preserve=mode,ownership,timestamps
        .. 'p'
        .. ' ' .. shellescape(src) .. ' ' .. shellescape(dst))

    if v:shell_error
        system('')
        Error('Failed to copy ' .. string(src) .. ' to ' .. string(dst))
    endif
enddef

def unix#grep(prg: string, args: string) #{{{1
    # TODO:
    # Make `find(1)` ignore files matching 'wildignore'.
    # https://stackoverflow.com/a/22558474/9477010
    var cmd: string = prg .. ' ' .. args .. ' 2>/dev/null'
    silent var items: list<dict<any>> = getqflist({
        lines: systemlist(cmd),
        efm: '%f'
    }).items
    if empty(items)
        return
    endif

    setqflist([], ' ', {items: items, title: '$ ' .. cmd})

    doautocmd <nomodeline> QuickFixCmdPost cwindow
    if &buftype == 'quickfix'
        qf#setMatches('unix:grep', 'Conceal', 'double_bar')
        qf#createMatches()
    endif

    # Old Code:{{{
    #
    #     var grepprg: string = &l:grepprg
    #     var bufnr: number = bufnr('%')
    #     var grepformat: string = &grepformat
    #     var shellpipe: string = &shellpipe
    #
    #     try
    #         # TODO:
    #         # Make `find(1)` ignore files matching 'wildignore'.
    #         # https://stackoverflow.com/a/22558474/9477010
    #         &l:grepprg = prg
    #         #              ┌ the output of `find(1)` and `locate(1)` will just contain file names
    #         #              │
    #         &l:grepformat=%f
    #         # The default value of 'shellpipe' ('2>&1| tee') causes the error messages
    #         # (e.g.: “permission denied“) to be included in the output of `:grep`.
    #         # It's noise, so we get rid of them by temporarily tweaking 'shellpipe'.
    #         &shellpipe = '| tee'
    #         # FIXME:
    #         # Don't use `:grep`, it makes the screen flicker.  Use `cgetexpr` instead.
    #         # Look at what we did in `myfuncs#opGrep()`.
    #
    #         #                   ┌ don't jump to first match, we want to decide ourselves
    #         #                   │ whether to jump
    #         #                   │
    #         execute 'silent grep! ' .. pat
    #         #        │
    #         #        └ bypass prompt “Press ENTER or type command to continue“
    #         # FIXME:
    #         redraw!
    #
    #         # No need to inform  our custom autocmds, responsible for dealing with
    #         # qf windows (opening, layout, ...), that we have just populated a qfl:
    #         #
    #         #     doautocmd <nomodeline> QuickFixCmdPost cwindow
    #         #
    #         # ... because `:vimgrep` has already triggered `QuickFixCmdPost`.
    #
    #         if !getqflist()->empty()
    #             setqflist([], 'a', {title: '$ ' .. prg .. ' ' .. pat})
    #
    #             if &buftype == 'quickfix'
    #                 qf#setMatches('eunuch:grep', 'Conceal', 'double_bar')
    #                 qf#createMatches()
    #             endif
    #
    #             # If we didn't use a bang when we executed `:Locate` or `:Find`, and
    #             # the command found sth, jump to the first match.
    #             # We give to a bang the same meaning as Vim does with `:grep` or `:make`.
    #             if !bang
    #                 cfirst
    #             endif
    #         endif
    #     catch
    #         return Catch()
    #     finally
    #         setbufvar(bufnr, '&grepprg', grepprg)
    #         &grepformat = grepformat
    #         &shellpipe = shellpipe
    #     endtry
    #}}}
    # TODO: Study the old code to understand why `:grep` was really a bad choice.{{{
    #
    # Hint: In addition to all the comments  it contains, there is also the fact
    # that  it runs  `:!` which  means  that Vim  automatically expands  special
    # characters,  which means  that you  need to  protect them,  which is  hard
    # because  `a:pat` is  not  necessarily  a pattern,  it  could be  arbitrary
    # arguments passed  to `$  find`.  So  you would first  need to  extract the
    # pattern from the arguments...
    #
    # ---
    #
    # Remember that `:grep`  is shitty because it causes the  screen to flicker,
    # due to the combination of `:silent` and `:redraw`:
    #
    #     nnoremap <F3> <Cmd>execute 'silent grep! foobar' <Bar> redraw!<CR>
    #                                 │                          │
    #                                 │                          └ needed to redraw screen
    #                                 └ needed to avoid seeing the terminal screen
    #
    # ---
    #
    # Also, study why `getqflist()` + `setqflist()` is probably better than `:cexpr`.
    # When should we use one or the other?
    # Review our usage of `:grep` and `:cexpr` (and all the variants) everywhere.
    #}}}
enddef

def unix#mkdir(dir: string, bang: bool) #{{{1
    var dest: string = empty(dir)
        ?     expand('%:p:h')
        : dir[0] == '/'
        ?     dir
        :     expand('%:p') .. dir

    try
        mkdir(dest, bang ? 'p' : '')
    catch
        Catch()
        return
    endtry
enddef

def unix#move(arg_dst: string, bang: bool) #{{{1
    var src: string = expand('%:p')
    var dst: string = arg_dst->fnamemodify(':p')

    # If the destination is a directory, it must be completed, by appending
    # the current filename.

    #  ┌ the destination is an existing directory
    #  │
    #  │                   ┌ or a future directory (we're going to create it)
    #  ├──────────────┐    ├────────────┐
    if isdirectory(dst) || dst[-1] == '/'
        #       ┌ make sure there's a slash
        #       │ between the directory and the filename
        #       ├─────────────────────────┐
        dst ..= (dst[-1] == '/' ? '' : '/') .. src->fnamemodify(':t')
        #                                      ├────────────────────┘
        #                                      └ add the current filename
        #                                        to complete the destination
    endif

    # If the directory of the destination doesn't exist, create it.
    if !dst->fnamemodify(':h')->isdirectory()
        dst->fnamemodify(':h')->mkdir('p')
    endif

    dst = simplify(dst)->substitute('^\.\/', '', '')

    # `:Mv` and `:Rename` should behave like `:saveas`.
    #
    #     :Mv     existing_file    ✘
    #     :Rename existing_file    ✘
    #     :saveas existing_file    ✘
    #
    # The operation shouldn't overwrite the file.
    # Except if we added a bang:
    #
    #     :Mv!     existing_file   ✔
    #     :Rename! existing_file   ✔
    #     :saveas! existing_file   ✔

    # The destination is occupied by an existing file, and no bang was added.
    # The command must fail.
    if filereadable(dst) && !bang
        # TODO: Handle this error: "E139: File is loaded in another buffer"
        # It happens if  the name we pass  to `:Rename` matches a  file which is
        # loaded  in  the current  Vim  session.   For  example, we  could  make
        # `:Rename!` wipe this buffer...
        execute 'keepalt saveas ' .. fnameescape(dst)
        #        │
        #        └ even though `:saveas` is going to fail, it will still
        #          change the alternate file for the current window (`dst`);
        #          we don't want that
        return

    # Try to rename current file.
    # What are the differences between `:saveas` and `rename()`:
    #
    #    - `rename()` gets rid of the old file, after the renaming; `:saveas` does *not*
    #    - `rename()` can move a file to a different filesystem; `:saveas` ?
    elseif rename(src, dst) != 0
        # If a problem occurred, inform us.
        Error('Failed to rename ' .. string(src) .. ' to ' .. string(dst))
        return
    else
        # If no pb occurred execute `:saveas! dst`.
        #
        # FIXME:
        # Why set the buffer as modified?
        &l:modified = true
        # FIXME:
        # Why this command? Maybe to trigger one (some?, all?) of those events:
        #
        #     BufNew
        #     BufFilePre
        #     BufFilePost
        #     BufAdd
        #     BufCreate
        #     BufWrite
        #     BufWritePre
        #     BufWritePost
        execute 'keepalt saveas! ' .. fnameescape(dst)

        # Get rid of old buffer (it's not linked to a file anymore).
        # But only if it's not the current one.
        # It could be the current one if we execute, by accident:
        #
        #     :Mv     /path/to/current/file
        #     :Rename current_filename
        if src != expand('%:p')
            execute 'silent! bwipeout ' .. fnameescape(src)
        endif

        # Rationale:{{{
        #
        # If we change  the filetype of the file (e.g.  `foo.sh` → `foo.py`), we
        # want to load the right filetype/syntax/indent plugins.
        #}}}
        filetype detect
        # re-apply fold settings
        doautocmd <nomodeline> BufWinEnter
    endif
enddef

def unix#renameComplete(arglead: string, _, _): string #{{{1
    var prefix: string = expand('%:p:h') .. '/'
    var files: list<string> = glob(prefix .. arglead .. '*', false, true)
        ->map((_, v: string) => v[strcharlen(prefix) :] .. (isdirectory(v) ? '/' : ''))
    return (files + ['../'])->join("\n")
    #                ^---^
    # TODO: How does Vim handle that?
enddef

def ShouldWriteBuffer(seen: dict<bool>): bool #{{{1
    # `'buftype'` is a  buffer-local option, whose value determines  the type of
    # buffer.  We want to write a buffer currently displayed in a window, iff:
    #
    #    - it is a regular buffer (&buftype = '')
    #
    #    - an autocmd listening to `BufWriteCmd` determines how it must be written
    #      (&buftype = 'acwrite')

    if !&readonly
    && &modifiable
    && (&buftype == '' || &buftype == 'acwrite')
    && !expand('%')->empty()
    && !seen->has_key(bufnr('%'))
        return true
    endif
    return false
enddef

def unix#wall() #{{{1
    var cur_winid: number = win_getid()
    seen = {}
    if !&readonly && !expand('%')->empty()
        seen[bufnr('%')] = true
        write
    endif
    tabdo windo if ShouldWriteBuffer(seen)
          |     write
          |     seen[bufnr('%')] = true
          | endif
    win_gotoid(cur_winid)
enddef

var seen: dict<bool>

def Error(msg: string) #{{{2
    echohl ErrorMsg
    echomsg msg
    echohl NONE
enddef

