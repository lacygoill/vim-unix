fu! unix#tree#dump(dir) abort "{{{1
    if !executable('tree')
        return 'echoerr '.string('requires the tree shell command; currently not installed')
    endif

    let tempfile = tempname().'/:Tree'
    exe 'lefta '.(&columns/3).'vnew '.tempfile

    let ignore_pat = printf('-I "%s"', '.git|'.substitute(&wig, ',', '|', 'g'))
    let dir = !empty(a:dir) ? shellescape(expand(a:dir),1) : ''
    "                ┌ print All entries, including hidden ones
    "                │┌ sort the output by last status change
    "                ││┌ print the full path for each entry (necessary for `gf` &friends)
    "                │││┌ append a `/' for directories, a `*' for executable file, ...
    "                ││││
    sil exe '.!tree -acfF --dirsfirst --noreport '.ignore_pat.' '.dir
    "                       │           │
    "                       │           └ don't print the file and directory report at the end
    "                       └ print directories before files

    " `$ tree` make the paths begin with an initial dot to stand for the working
    " directory.
    " But the  latter could change after  we change the focus  to another window
    " (`vim-cwd`).
    " This could break `C-w f`.
    "
    " We need to translate the dot into the current working directory.
    let cwd = getcwd()
    sil! %s:─\s\zs\.\ze/:\=cwd:
endfu

fu! unix#tree#fde() abort "{{{1
    let idx = matchend(split(getline(v:lnum), '\zs'), '[├└]')
    let lvl = idx/4
    if matchstr(getline(v:lnum + 1), '\%'.(idx+5).'v.') =~# '[├└]'
        return '>'.(lvl + 1)
    endif
    return lvl
endfu

fu! unix#tree#fdt() abort "{{{1
    let pat = '\(.*─\)\(.*\)'
    let l:Rep = {-> repeat(' ', strchars(submatch(1), 1)).substitute(submatch(2), '.*/\ze.', '', '')}
    return (get(b:, 'foldtitle_full', 0) ? '['.(v:foldend - v:foldstart).']': '')
    \      .substitute(getline(v:foldstart), pat, l:Rep, '')
endfu

