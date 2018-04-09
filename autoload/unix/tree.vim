if exists('g:autoloaded_unix#tree')
    finish
endif
let g:autoloaded_unix#tree = 1

let s:cache = {}

fu! unix#tree#close() abort "{{{1
    if !has_key(s:cache, getline(1))
        close
        return
    endif
    " save last position in this directory before closing the window
    let s:cache[getline(1)].pos = line('.')
    close
endfu

fu! unix#tree#dump(dir) abort "{{{1
    if !executable('tree')
        return 'echoerr '.string('requires the tree shell command; currently not installed')
    endif

    let tempfile = tempname().'/:Tree'
    exe 'lefta '.(&columns/3).'vnew '.tempfile

    let cwd = getcwd()
    let dir = !empty(a:dir) ? expand(a:dir) : cwd
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
    let short_options = '-cfF'.(get(s:, 'hide_dot_entries', 0) ? '' : ' -a')
    let long_options = '--dirsfirst --noreport'
    "                     │           │
    "                     │           └ don't print the file and directory report at the end
    "                     └ print directories before files
    let ignore_pat = printf('-I "%s"', '.git|'.substitute(&wig, ',', '|', 'g'))
    let limit = '-L '.(s:is_big_directory(dir) ? 3 : 10).' --filelimit 300'
    "             │                                          │
    "             │                                          └ do not descend directories
    "             │                                            that contain more than 300 entries
    "             │
    "             └ don't display directories whose depth is greater than 3 or 10

    sil exe '.!tree '.short_options.' '.long_options.' '.limit.' '.ignore_pat.' '.shellescape(dir,1)

    " `$  tree` makes  the paths  begin with  an initial  dot to  stand for  the
    " working directory.
    " But the  latter could change after  we change the focus  to another window
    " (`vim-cwd`).
    " This could break `C-w f`.
    "
    " We need to translate the dot into the current working directory.
    sil! %s:─\s\zs\.\ze/:\=cwd:

    " save the contents of the buffer in a cache, for quicker access in the future
    call extend(s:cache, {dir : {'contents': getline(1, '$')}})
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

fu! s:getfile() abort "{{{1
    let line = getline('.')

    return line =~# '\s->\s'
    \ ?        matchstr(line, '.*─\s\zs.*\ze\s->\s')
    \ :        matchstr(line, '.*─\s\zs.*[/=*>|]\@<!')
endfu

fu! unix#tree#hide_dot_entries() abort "{{{1
    let s:hide_dot_entries = !get(s:, 'hide_dot_entries', 0)
    call unix#tree#reload()
endfu

fu! s:is_big_directory(dir) abort "{{{1
    return a:dir is# '/'
    \ ||   a:dir is# '/home'
    \ ||   a:dir =~# '^/home/[^/]\+/\?$'
    \ ||   systemlist('find '.a:dir.' -type f | wc -l')[0] > 10000
endfu

fu! unix#tree#open(where) abort "{{{1
    let file = s:getfile()
    if a:where is# 'split'
        exe 'sp '.file
    else
        exe 'tabedit '.file
    endif
endfu

fu! unix#tree#relative_dir(who) abort "{{{1
    if a:who is# 'parent'
        if getline(1) is# '/'
            return
        endif
        let new_dir = fnamemodify(substitute(getline(1), '^\.', getcwd(), ''), ':h')
    else
        if line('.') ==# 1
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
    let cur_dir = getline(1)
    if has_key(s:cache, cur_dir)
        call remove(s:cache, cur_dir)
    endif
    close
    exe 'Tree '.cur_dir
endfu

