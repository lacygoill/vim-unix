if exists('g:autoloaded_unix#tree')
    finish
endif
let g:autoloaded_unix#tree = 1

let s:cache = {}
let s:hide_dot_entries = 0

" TODO:
" How to make the buffer survive a `:e`, like a dirvish buffer?

" TODO:
" Implement `yy`, `dd`, `dD`, to copy, cut, delete (trash-put) a file.

" TODO:
" :Tree /proc
"
"                           ┌ everything is colored as a directory
"         ┌─────────────────┤
"     ├── /proc/self -> 2827/
"         └───────────┤ └───┤
"                     │     └ this should be colored as a directory
"                     └ this should be colored as a link
"
" Also:
"     :Tree ~
"
" Look at the `.zsh/` directory:
"
"                                        ┌ is currently concealed
"         ┌──────────────────────────────┤
"         │                              │   ┌ is currently colored as a directory
"         │                              │┌──┤
"     ├── /home/jean/.zsh -> Dropbox/conf/zsh/
"         └────────────────┤ └───────────────┤
"                          │                 └ this should be colored as a directory
"                          └ this should be colored as a link

" TODO:
" The name  of the  current directory  in the  statusline is  `tree_viewer` when
" we're in root folder, and the window is non-focused.
" It should be `/`.

" TODO:
" Sort hidden directories after non-hidden ones.

" TODO:
" Correctly position the cursor when we hide dot entries.

fu! unix#tree#close() abort "{{{1
    let curdir = s:getcurdir()
    if !has_key(s:cache, curdir)
        close
        return
    endif
    " save last position in this directory before closing the window
    let s:cache[curdir].pos = line('.')
    close
endfu

fu! unix#tree#fde() abort "{{{1
    let idx = matchend(split(getline(v:lnum), '\zs'), '[├└]')
    let lvl = idx/4
    if matchstr(getline(v:lnum + 1), '\%'.(idx+5).'v.') =~# '[├└]'
        return '>'.(lvl + 1)
    endif
    return lvl
endfu

fu! unix#tree#fdl() abort "{{{1
    let &l:fdl = &foldclose is# 'all' ? 0 : 99
endfu

fu! unix#tree#fdt() abort "{{{1
    let pat = '\(.*─\s\)\(.*\)'
    let l:Rep = {-> submatch(1).substitute(submatch(2), '.*/\ze.', '', '')}
    return (get(b:, 'foldtitle_full', 0) ? '['.(v:foldend - v:foldstart).']': '')
    \      .substitute(getline(v:foldstart), pat, l:Rep, '')
endfu

fu! s:get_ignore_pat() abort "{{{1
    " Purpose:
    " Build a FILE pattern to pass to `$ tree`, so that it ignores certain entries.
    " We use 'wig' to decide what to ignore.

    " 'wig' can contain patterns matching directories.
    " But  `$ tree`  compares the  patterns we  pass to  `-I` to  the LAST  path
    " component of the entries (files/directories).
    " So, you can't do this:
    "
    "         $ tree -I '*/__pycache__/*' ~/.vim/pythonx/
    "
    " Instead, you must do this:
    "
    "         $ tree -I '__pycache__' ~/.vim/pythonx/

    "                   ┌ to match `*.bak` in `&wig`
    "                   │
    "                   │              ┌ to match `*/pycache/*`
    "                   │              │
    "                   │              │                ┌ to match `tags`
    "          ┌────────┤        ┌─────┤        ┌───────┤
    let pat = '\*\.[^/]\+\|\*/\zs[^*/]\+\ze/\*\|^[^*/]\+$'
    let ignore_pat = map(split(&wig, ','), {i,v -> matchstr(v, pat)})
    " We may get empty matches, or sth like `*.*` because of (in vimrc):
    "
    "         let &wig .= ','.&undodir.'/*.*'
    "
    " We must eliminate those.
    call filter(ignore_pat, {i,v -> !empty(v) && v !~# '^[.*/]\+$'})
    let ignore_pat = join(ignore_pat, '|')

    return printf('-I "%s"', ignore_pat)
endfu

fu! s:get_tree_cmd(dir) abort "{{{1
    "                     ┌ print the full path for each entry (necessary for `gf` &friends)
    "                     │┌ append a `/' for directories, a `*' for executable file, ...
    "                     ││
    let short_options = '-fF'.(s:hide_dot_entries ? '' : ' -a')
    let long_options = '--dirsfirst --noreport'
    "                     │           │
    "                     │           └ don't print the file and directory report at the end
    "                     └ print directories before files

    let ignore_pat = s:get_ignore_pat()

    let limit = '-L '.(s:is_big_directory(a:dir) ? 2 : 10).' --filelimit 300'
    "             │                                            │
    "             │                                            └ do not descend directories
    "             │                                              that contain more than 300 entries
    "             │
    "             └ don't display directories whose depth is greater than 2 or 10

    return '.!tree '.short_options.' '.long_options.' '.limit.' '.ignore_pat.' '.shellescape(a:dir,1)
endfu

fu! s:getcurdir() abort "{{{1
    let curdir = matchstr(expand('%:p'), 'tree_viewer::\zs.*')
    return empty(curdir) ? '/' : curdir
endfu

fu! s:getfile() abort "{{{1
    let line = getline('.')

    return line =~# '\s->\s'
    \ ?        matchstr(line, '.*─\s\zs.*\ze\s->\s')
    \ :        matchstr(line, '.*─\s\zs.*[/=*>|]\@<!')
    " Do NOT add the `$` anchor !                   ^{{{
    "
    " You don't want match until the end of the line.
    " You want to match  a maximum of text, so maybe until the  end of the line,
    " but with the condition until that it doesn't finish with [/=*>|].
    "}}}
endfu

fu! s:is_big_directory(dir) abort "{{{1
    return a:dir is# '/'
    \ ||   a:dir is# '/home'
    \ ||   a:dir =~# '^/home/[^/]\+/\?$'
    \ ||   systemlist('find '.a:dir.' -type f 2>/dev/null | wc -l')[0] > 5000
endfu

fu! unix#tree#open(where) abort "{{{1
    let file = s:getfile()
    if a:where is# 'split'
        exe 'sp '.file
    else
        exe 'tabedit '.file
    endif
endfu

fu! unix#tree#populate(dir) abort "{{{1
    if !executable('tree')
        return 'echoerr '.string('requires the tree shell command; currently not installed')
    endif

    let cwd = getcwd()
    let dir = !empty(a:dir) ? expand(a:dir) : cwd
    let dir = substitute(dir, '.\{-1,}\zs/\+$', '', '')

    if !isdirectory(dir)
        return 'echoerr '.string(dir.'/ is not a directory')
    endif

    let tempfile = tempname().'/tree_viewer::'.(dir is# '/' ? '' : dir)
    exe 'lefta '.(&columns/3).'vnew '.tempfile
    " Can be used  by `vim-statusline` to get the directory  viewed in a focused
    " `tree` window.
    let b:curdir = dir

    " If we've already visited this directory, no need to re-invoke `$ tree`.
    " Just use the cache.
    if has_key(s:cache, dir) && has_key(s:cache[dir], 'contents')
        sil 0put =s:cache[dir].contents
        $d_
        " also restore last position if one was saved
        if has_key(s:cache[dir], 'pos')
            exe s:cache[dir].pos
        endif
        return ''
    endif

    sil exe s:get_tree_cmd(dir)

    " `$  tree` makes  the paths  begin with  an initial  dot to  stand for  the
    " working directory.
    " But the  latter could change after  we change the focus  to another window
    " (`vim-cwd`).
    " This could break `C-w f`.
    "
    " We need to translate the dot into the current working directory.
    sil! keepj keepp %s:─\s\zs\.\ze/:\=cwd:
    " Why?{{{
    "
    " We  may have  created a  symbolic link  whose target  is a  directory, and
    " during the creation we may have appended a slash at the end.
    " If that's the case, because of the `-F` option, `$ tree` will add a second
    " slash.  We'll end up with two  slashes, which will give unexpected results
    " regarding the syntax highlighting.
    "}}}
    sil! keepj keepp %s:/\ze/$::

    " save the contents of the buffer in a cache, for quicker access in the future
    call extend(s:cache, {dir : {'contents': getline(1, '$')}})
endfu

fu! unix#tree#relative_dir(who) abort "{{{1
    if a:who is# 'parent'
        let curdir = s:getcurdir()
        if curdir is# '/'
            return
        endif
        let new_dir = fnamemodify(substitute(curdir, '^\.', getcwd(), ''), ':h')
    else
        "                                                   ┌ don't try to open an entry
        "                                                   │ for which `$ tree` encountered an error
        "                                                   │ (ends with a message in square brackets)
        "                                      ┌────────────┤
        if line('.') ==# 1 || getline('.') =~# '\s\[.\{-}\]$'
            return
        endif
        let new_dir = s:getfile()
        if !isdirectory(new_dir)
            exe 'e '.new_dir
            return
        endif
    endif

    call unix#tree#close()
    exe 'Tree '.new_dir

    " If we go up the tree, position the cursor on the directory we come from.
    if exists('curdir')
        call search('\C\V─\s'.curdir.'/\$')
    endif
endfu

fu! unix#tree#reload() abort "{{{1
    " remove information in cache, so that  the reloading is forced to re-invoke
    " `$ tree`
    let cur_dir = s:getcurdir()
    if has_key(s:cache, cur_dir)
        call remove(s:cache, cur_dir)
    endif

    " grab current line; necessary to restore position later
    let line = getline('.')
    " if the  current line matches a  hidden file/directory, and we're  going to
    " hide dot  entries, we won't  be able to  restore the position;  instead we
    " will restore  the position using the  previous line which is  NOT a hidden
    " entry
    if line =~# '.*/\.[^/]\+/\?$' && s:hide_dot_entries
        let line = getline(search('.*/[^.][^/]\{-}/\?$', 'bnW'))
    endif

    " reload
    close
    exe 'Tree '.cur_dir

    " restore position
    let pat = '\C\V\^'.escape(line, '\').'\$'
    let pat = substitute(pat, '[├└]', '\\m[├└]\\V', 'g')
    call search(pat)
endfu

fu! unix#tree#toggle_dot_entries() abort "{{{1
    let s:hide_dot_entries = !s:hide_dot_entries
    call unix#tree#reload()
endfu

