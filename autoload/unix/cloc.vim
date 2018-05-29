" Purpose:{{{
"
" Populate the global variable `g:cloc_results` with a dictionary.
" Each key of this dictionary is a programming language (except one named SUM:).
" Each value is another dictionary.
"
" This sub-dictionary should contain the 4 following keys:
"
"     ┌─────────┬────────────────────────────────────────────────────────────────┐
"     │ files   │ " nr of files under the path whose language is the name of the │
"     │         │ dictionary                                                     │
"     ├─────────┼────────────────────────────────────────────────────────────────┤
"     │ code    │ "           total lines of code for this language              │
"     ├─────────┼────────────────────────────────────────────────────────────────┤
"     │ comment │ "           total comment lines "                              │
"     ├─────────┼────────────────────────────────────────────────────────────────┤
"     │ blank   │ "           total blank lines   "                              │
"     └─────────┴────────────────────────────────────────────────────────────────┘
"}}}


" If you're only interested in the variable and don't want to see the output
" of `$ cloc`, execute the command silently:
"
"     :sil Cloc [/path]


" FIXME:
" make the code async (so that it doesn't block when we use `:Cloc` on a big
" directory)

" TODO:
" Use the `--csv` option. It makes the output easier to parse.

fu! unix#cloc#main(lnum1,lnum2,path) abort "{{{1
    if !empty(a:path)
        if a:path =~# '^http'
            let tempdir = tempname()
            let git_output = system('git clone '.a:path.' '.tempdir)
            let to_scan = tempdir
        else
            let to_scan = a:path
        endif
    else
        let file    = tempname()
        let to_scan = file.'.'.(empty(expand('%:e')) ? &ft : expand('%:e'))
        let lines   = getline(a:lnum1, a:lnum2)
        call writefile(lines, to_scan)

        " In a string, it seems that `.` can match anything including a newline.
        " Like `\_.`.

        " Warning: there seems to be a limit on the size of the shell's standard input.{{{
        "
        " We could use this code instead:
        "
        "     let lines = shellescape(join(getline(a:lnum1,a:lnum2), "\n"))
        "     echo system('echo '.lines.' | cloc --stdin-name=foo.'.&ft.' -')
        "
        " But because of the previous limit:
        "
        "     http://stackoverflow.com/a/19355351
        "
        " … the command would error out when send too much text.
        " The error would like like this:
        "
        "     E484: Can't open file /tmp/user/1000/vsgRgDU/97
        "
        " Currently, on my system, it seems to error out somewhere above 120KB.
        " In a file, to go the 120 000th byte, use the normal `go` command and hit
        " `120000go`. Or the Ex version:
        "
        "     :120000go
        "}}}
    endif

    let cmd = 'cloc --exclude-dir=.cache,t,test '.to_scan
    " remove the header
    let output_cloc = matchstr(system(cmd), '\zs-\+.*')

    " Why do store the output in a variable, and echo it at the very end of
    " the function? Why don't we echo it directly?
    " Because, if the output is longer than the screen, and Vim uses its pager
    " to display it, and if we don't go down the output but cancel/exit, it
    " seems the rest of the code wouldn't be executed. We would have no
    " `g:cloc_results` variable.
    " We delay the display of the output to the very end of the function, to
    " be sure the code generating `g:cloc_results` is processed.

    let to_display = output_cloc

    " the 1st `split()` splits the string into a list, each item being a line
    " `filter()`        removes the lines which don't contain numbers
    " `map()`           replaces the lines with (sub)lists, each item being a number
    "                   (number of blank lines, lines of code, comments, files)

    " We ask `map()` to split all the lines in the output of `$ cloc`
    " using the pattern `\s\{2,}\ze\d`.
    " Why `\s\{2,}` and not simply `\s\+`?
    "
    " Because there are some programming languages which contain a number in
    " their name.
    " For example, in the source code of `$ cloc`, we find `Fortran 77` and
    " `Fortran 99`. With `\s\+`, we would split in the middle of the language.
    " With `\s\{2,}`, it shouldn't occur, unless some weird languages use
    " more than 2 consecutive spaces in their name…

    let output_cloc = map(filter(split(output_cloc, '\n'),
    \                            { i,v -> v =~# '\d\+' }),
    \                     { i,v -> split(v, '\s\{2,}\ze\d') })

    let g:cloc_results = {}
    let keys           = ['files', 'blank', 'comment', 'code']

    for values_on_line in output_cloc
        " `i`    is going to index the `keys` list
        " `dict` is going to store a dictionary containing the numbers
        "        of lines for a given language
        let i    = 0
        let dict = {}

        for value in values_on_line[1:]
            let dict[keys[i]] = eval(value)
            let i += 1
        endfor

        let g:cloc_results[values_on_line[0]] = dict
    endfor

    echo to_display
endfu

fu! unix#cloc#count_lines_in_func() abort "{{{1
    let view = winsaveview()
    norm [m
    let lnum1 = line('.')+1
    norm ]M
    let lnum2 = line('.')-1
    sil call unix#cloc#main(lnum1,lnum2,'')
    let ft = get({'vim': 'vim script', 'sh': 'Bourne Shell',}, &ft, '')
    if ft is# ''
        echo 'non supported filetype'
        return
    endif
    let blank_cnt = get(get(g:cloc_results, ft, {}), 'blank', 0)
    let comment_cnt = get(get(g:cloc_results, ft, {}), 'comment', 0)
    let code_cnt = get(get(g:cloc_results, ft, {}), 'code', 0)
    echo printf('blank: %s   comment: %s   code: %s', blank_cnt, comment_cnt, code_cnt)
    call winrestview(view)
endfu

