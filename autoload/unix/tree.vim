if exists('g:autoloaded_unix#tree')
    finish
endif
let g:autoloaded_unix#tree = 1

let s:cache = {}
let s:hide_dot_entries = 0
let s:INDICATOR = '[/=*>|]'

" TODO: Implement `yy`, `dd`, `tp`, to copy, cut, delete (trash-put) a file.

" TODO: How to make the buffer survive a `:e`, like a dirvish buffer?

" TODO: Sort hidden directories after non-hidden ones.

" TODO: Implement `g?` to show mappings, and the complete `$ tree` command which
" was used to generate the tree.

" TODO: Study `syntax/` and infer some rules from it. Note them somewhere.
" Also, refactor this file; it has become a little complex.
" Split it into several files, or into several categories (interface, core, misc).
" Also, try to make each function fit on one single screen (with folding).

" TODO:
" Remove the cache after a few minutes to prevent it from taking too much memory.
" Or better,  find a  way to  measure its size,  and when  it exceeds  a certain
" amount, only remove some keys (the biggest?, the oldest?).
"
" There's no function to get the size of a dictionary.
" But we could do:
"
"         let size = strlen(string(dictionary))
"
" And after every display  of a layout, we would update a  key storing the total
" size of the cache.

" TODO:
" Add preview mode.
" `p` should preview the file under the cursor.
" `cop` should preview any file while our cursor is moving.
"
" Also, after pressing `cop`,  if our cursor is on a  directory and its contents
" is too  big to  be displayed in  the current tree  buffer, the  preview window
" should show it nonetheless.
" It would  be useful to  see what's in there,  without losing the  current tree
" layout.

" FIXME:
"     :Tree ~/Dropbox/
"     gg
"     C-l
"     Z C-l or Z C-h
"     smash ; and ,
"
" It's slow, and consumes 30% of cpu.
" Profile and optimize syntax highlighting.

" TODO:
" Do you think the name of the buffer is right?
"
" In this plugin:
"     https://github.com/thinca/vim-editvar/blob/master/plugin/editvar.vim
"
" The name of the special buffer is simply:
"     editvar://{variable_name}
"
" If we followed the same scheme, we would use:
"     tree_viewer:///path/to/file
"
" instead of:
"     /tmp/v.../../tree_viewer::/path/to/file
"
" What's the best choice?
" Why using `tempname()`?
" `::` vs `://`?

" TODO:
" Color special files (socket, ...).

" TODO:
" For a plugin, maybe we should also support a diagram using only ascii chars.
" We would need to use the option `--charset=ascii`, and we would need to tweak
" some regexes whenever they contain `─` (→  --), `└` (→ `--), `├` (|--).

fu! unix#tree#close() abort "{{{1
    let curdir = s:getcurdir()
    if !has_key(s:cache, curdir)
        close
        return
    endif
    " save the view in this directory before closing the window
    call s:save_view(curdir)
    close
endfu

fu! unix#tree#fde() abort "{{{1
    " Warning:{{{
    " This function is by far the slowest when we execute `:Tree`.
    " This is due to the `let idx =` and `if matchstr()` statements.
    "
    " As a result, `:Tree /proc` is slow the first time:
    "
    "         $ vim --cmd 'prof  start /tmp/script.profile' \
    "               --cmd 'prof! file  */tree.vim' \
    "               -c    ':Tree /proc' \
    "               -cq
    "
    "         :q
    "
    "         $ vim /tmp/script.profile
    "}}}
    let idx = strchars(matchstr(getline(v:lnum), '.\{-}[├└]'))-1
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
    let pat = '\(.*─\s\)\(.*\)/'
    let l:Rep = {-> submatch(1).substitute(submatch(2), '.*/', '', '')}
    return (get(b:, 'foldtitle_full', 0) ? '['.(v:foldend - v:foldstart).']': '')
    \      .substitute(getline(v:foldstart), pat, l:Rep, '')
endfu

fu! s:format() abort "{{{1
    " `$  tree` makes  the paths  begin with  an initial  dot to  stand for  the
    " working directory.
    " But the  latter could change after  we change the focus  to another window
    " (`vim-cwd`).
    " This could break `C-w f`.
    "
    " We need to translate the dot into the current working directory.
    let cwd = getcwd()
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
    "                   │ (no dot in the pattern to also match `*~`)
    "                   │
    "                   │            ┌ to match `*/pycache/*`
    "                   │            │
    "                   │            │                ┌ to match `tags`
    "          ┌────────┤      ┌─────┤        ┌───────┤
    let pat = '\*[^/]\+\|\*/\zs[^*/]\+\ze/\*\|^[^*/]\+$'
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
    "                     ││┌ turn colorization off
    "                     │││
    let short_options = '-fFn'.(s:hide_dot_entries ? '' : ' -a')
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

    return 'tree '.short_options.' '.long_options.' '.limit.' '.ignore_pat.' '.shellescape(a:dir,1)
endfu

fu! s:getcurdir() abort "{{{1
    let curdir = matchstr(expand('%:p'), 'tree_viewer::\zs.*')
    return empty(curdir) ? '/' : curdir
endfu

fu! s:getfile() abort "{{{1
    let line = getline('.')

    return line =~# '\s->\s'
    \ ?        matchstr(line, '.*─\s\zs.*\ze\s->\s')
    \ :        matchstr(line, '.*─\s\zs.*'.s:INDICATOR.'\@<!')
    " Do NOT add the `$` anchor !                           ^{{{
    "
    " You don't want match until the end of the line.
    " You want to match  a maximum of text, so maybe until the  end of the line,
    " but with the condition that it doesn't finish with [/=*>|].
    "}}}
endfu

fu! s:is_big_directory(dir) abort "{{{1
    return a:dir is# '/'
    \ ||   a:dir is# '/home'
    \ ||   a:dir =~# '^/home/[^/]\+/\?$'
    \ ||   systemlist('find '.a:dir.' -type f 2>/dev/null | wc -l')[0] > 10000
endfu

fu! unix#tree#open(where) abort "{{{1
    let file = s:getfile()
    if a:where is# 'split'
        exe 'sp '.file
    else
        exe 'tabedit '.file
    endif
endfu

fu! s:open(dir, nosplit) abort "{{{1
    let tempfile = tempname().'/tree_viewer::'.(a:dir is# '/' ? '' : a:dir)
    if a:nosplit
        exe 'e '.tempfile
    else
        exe 'lefta '.get(s:, 'cur_width', &columns/3).'vnew '.tempfile
    endif
    " Can be used  by `vim-statusline` to get the directory  viewed in a focused
    " `tree` window.
    let b:curdir = a:dir
endfu

fu! unix#tree#populate(dir, nosplit) abort "{{{1
    if !executable('tree')
        return 'echoerr '.string('requires the tree shell command; currently not installed')
    endif

    " save current file name to position the cursor on it
    if a:dir is# ''
        let current_file_pat = '\C\V─\s'.expand('%:p').'\m\%('.s:INDICATOR.'\|\s->\s\|$\)'
    endif

    let dir = !empty(a:dir) ? expand(a:dir) : expand('%:p:h')
    let dir = substitute(dir, '.\{-1,}\zs/\+$', '', '')
    if !isdirectory(dir)
        return 'echoerr '.string(dir.'/ is not a directory')
    endif
    call s:open(dir, a:nosplit)

    " If we've already visited this directory, no need to re-invoke `$ tree`.
    " Just use the cache.
    if has_key(s:cache, dir) && has_key(s:cache[dir], 'contents')
        return s:use_cache(dir)
    endif

    let cmd = s:get_tree_cmd(dir)
    call setline(1, systemlist(cmd))
    call s:format()

    if stridx(cmd, '-L 2 --filelimit 300') == -1
        " save the contents of the buffer in a cache, for quicker access in the future
        call extend(s:cache, {dir : {'contents': getline(1, '$'), 'big': 0}})
    else
        call matchadd('WarningMsg', '\%1l.*')
        call extend(s:cache, {dir : {'contents': getline(1, '$'), 'big': 1}})
        "                                                                ^
        " When an entry of the cache contains a non-zero 'big' key, it means the
        " directory is too big for all of its contents to be displayed.
        " We use this info  to highlight the path of a too  big directory on the
        " first line.
    endif

    " position cursor on current file
    if exists('current_file_pat')
        call search(current_file_pat)
    endif

    return ''
endfu

fu! s:put_cache(dir) abort "{{{1
    call setline(1, s:cache[a:dir].contents)

    " restore last position if one was saved
    if has_key(s:cache[a:dir], 'pos')
        exe s:cache[a:dir].pos
    endif

    " restore last foldlevel if one was saved
    if has_key(s:cache[a:dir], 'fdl')
        let &l:fdl = s:cache[a:dir].fdl
    endif
endfu

fu! unix#tree#relative_dir(who) abort "{{{1
    let curdir = s:getcurdir()

    if a:who is# 'parent'
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
            let id = win_getid()
            wincmd p
            " If we keep pressing  `l` on a file, we don't  want to keep opening
            " splits forever.
            if new_dir isnot# expand('%:p')
                exe 'sp '.new_dir
                norm! zv
            endif
            call win_gotoid(id)
            return
        endif
    endif

    call s:save_view(curdir)
    exe 'Tree! '.new_dir

    " If we go up the tree, position the cursor on the directory we come from.
    if exists('curdir')
        call search('\C\V─\s'.curdir.'\m\%(\s->\s\|/$\)')
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

    " reload
    exe 'Tree! '.cur_dir

    " restore position
    let pat = '\C\V\^'.escape(line, '\').'\$'
    let pat = substitute(pat, '[├└]', '\\m[├└]\\V', 'g')
    call search(pat)
endfu

fu! s:save_view(curdir) abort "{{{1
    let s:cache[a:curdir].pos = line('.')
    let s:cache[a:curdir].fdl = &l:fdl
endfu

fu! s:use_cache(dir) abort "{{{1
    call s:put_cache(a:dir)
    if exists('current_file_pat')
        call search(current_file_pat)
    endif
    " if the  directory is big, and  not all its contents  can be displayed,
    " highlight its path on the first line as an indicator
    if s:cache[a:dir].big
        call matchadd('WarningMsg', '\%1l.*')
    endif
    return ''
endfu

fu! unix#tree#toggle_dot_entries() abort "{{{1
    let s:hide_dot_entries = !s:hide_dot_entries
    call unix#tree#reload()
endfu

