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
" Look at the `zsh/` directory.

" TODO:
" The name  of the  current directory  in the  statusline is  `tree_viewer` when
" we're in root folder, and the window is non-focused.
" It should be `/`.

" FIXME:
" We still have issues with the restoration of the cursor position after `gh`.
" Try in home folder.

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

fu! s:getcurdir() abort "{{{1
    let curdir = matchstr(expand('%:p'), 'tree_viewer::\zs.*')
    return empty(curdir) ? '/' : curdir
endfu

fu! s:getfile() abort "{{{1
    let line = getline('.')

    return line =~# '\s->\s'
    \ ?        matchstr(line, '.*─\s\zs.*\ze\s->\s')
    \ :        matchstr(line, '.*─\s\zs.*[/=*>|]\@<!')
endfu

fu! unix#tree#toggle_dot_entries() abort "{{{1
    let s:hide_dot_entries = !s:hide_dot_entries
    call unix#tree#reload()
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

    "                     ┌ sort the output by last status change
    "                     │┌ print the full path for each entry (necessary for `gf` &friends)
    "                     ││┌ append a `/' for directories, a `*' for executable file, ...
    "                     │││
    let short_options = '-cfF'.(s:hide_dot_entries ? '' : ' -a')
    let long_options = '--dirsfirst --noreport'
    "                     │           │
    "                     │           └ don't print the file and directory report at the end
    "                     └ print directories before files
    let ignore_pat = printf('-I "%s"', '.git|'.substitute(&wig, ',', '|', 'g'))
    let limit = '-L '.(s:is_big_directory(dir) ? 2 : 10).' --filelimit 300'
    "             │                                          │
    "             │                                          └ do not descend directories
    "             │                                            that contain more than 300 entries
    "             │
    "             └ don't display directories whose depth is greater than 2 or 10

    sil exe '.!tree '.short_options.' '.long_options.' '.limit.' '.ignore_pat.' '.shellescape(dir,1)

    " `$  tree` makes  the paths  begin with  an initial  dot to  stand for  the
    " working directory.
    " But the  latter could change after  we change the focus  to another window
    " (`vim-cwd`).
    " This could break `C-w f`.
    "
    " We need to translate the dot into the current working directory.
    sil! keepj keepp %s:─\s\zs\.\ze/:\=cwd:

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
    if line =~# '.*/\.\%(.*/\)\@!' && s:hide_dot_entries
        let line = getline(search('─\s.*/[^.]\%(.*/\)\@!', 'bnW'))
    endif

    " reload
    close
    exe 'Tree '.cur_dir

    " restore position
    let pat = '\C\V\^'.escape(line, '\').'\$'
    let pat = substitute(pat, '[├└]', '\\m[├└]\\V', 'g')
    call search(pat)
endfu

