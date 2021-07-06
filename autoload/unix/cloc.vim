vim9script noclear

# Purpose:{{{
#
# Populate the global variable `g:cloc_results` with a dictionary.
# Each key of this dictionary is a programming language (except one named SUM:).
# Each value is another dictionary.
#
# This sub-dictionary should contain the 4 following keys:
#
#    ┌─────────┬────────────────────────────────────────────────────────────────┐
#    │ files   │ " nr of files under the path whose language is the name of the │
#    │         │ dictionary                                                     │
#    ├─────────┼────────────────────────────────────────────────────────────────┤
#    │ code    │ "           total lines of code for this language              │
#    ├─────────┼────────────────────────────────────────────────────────────────┤
#    │ comment │ "           total comment lines "                              │
#    ├─────────┼────────────────────────────────────────────────────────────────┤
#    │ blank   │ "           total blank lines   "                              │
#    └─────────┴────────────────────────────────────────────────────────────────┘
#}}}


# If you're only interested in the variable  and don't want to see the output of
# `cloc`, execute the command silently:
#
#     :silent Cloc [/path]


# FIXME:
# make the code async (so that it doesn't block when we use `:Cloc` on a big
# directory)

# TODO:
# Use the `--csv` option.  It makes the output easier to parse.

def unix#cloc#main( #{{{1
    lnum1: number,
    lnum2: number,
    path: string
)
    if !executable('cloc')
        # We need `:unsilent` because we may call this function with `:silent`.
        unsilent echomsg '`cloc` is not installed, or it''s not in the $PATH of the current user'
        return
    endif
    var to_scan: string
    if !empty(path)
        if path =~ '^http'
            var tempdir: string = tempname()
            var cmd: string = path =~ 'bitbucket' ? 'hg' : 'git'
            silent var git_output: string = system(cmd .. ' clone ' .. path .. ' ' .. tempdir)
            to_scan = tempdir
        else
            to_scan = path
        endif
    else
        var file: string = tempname()
        to_scan = file .. '.' .. (expand('%:e')->empty() ? &filetype : expand('%:e'))
        # TODO: Currently, `cloc(1)` does not recognize the new Vim9 comment leader (`#`).{{{
        #
        # As a result, it parses any Vim9 commented line as a line of code.
        # This makes the results wrong.
        #
        # We temporarily fix that by replacing `#` with `"`.
        #
        # In the future, consider opening an issue here:
        # https://github.com/AlDanial/cloc/issues
        #
        # I don't do it now, because Vim9 is still in development.
        # Maybe  cloc's  developer will  refuse  to  do anything  until  the
        # language is officially released.
        #}}}
        if b:current_syntax == 'vim9'
            getline(lnum1, lnum2)
                ->map((_, v: string) => v->substitute('^\s*\zs#', '"', ''))
                ->writefile(to_scan)
        else
            getline(lnum1, lnum2)->writefile(to_scan)
        endif

        # In a string, it seems that `.` can match anything including a newline.
        # Like `\_.`.

        # Warning: there seems to be a limit on the size of the shell's standard input.{{{
        #
        # We could use this code instead:
        #
        #     var lines: string = getline(lnum1, lnum2)->join("\n")->shellescape()
        #     silent var out: string = system('echo ' .. lines .. ' | cloc --stdin-name=foo.' .. &filetype .. ' -')
        #     echo out
        #
        # But because of the previous limit:
        # http://stackoverflow.com/a/19355351
        #
        # ... the command would error out when send too much text.
        # The error would like like this:
        #
        #     E484: Can't open file /tmp/user/1000/vsgRgDU/97˜
        #
        # Currently, on my system, it seems to error out somewhere above 120KB.
        # In a file, to  go the 120 000th byte, use the  normal `go` command and
        # hit `120000go`.  Or the Ex version:
        #
        #     :120000 go
        #}}}
    endif

    var cmd: string = 'cloc --exclude-lang=Markdown --exclude-dir=.cache,t,test ' .. to_scan
    silent var output_cloc: list<string> = system(cmd)
        # remove the header
        ->matchstr('\zs-\+.*')
        ->split('\n')

    # Why do you store the output in a variable, and echo it at the very end of the function?
    # Why don't you echo it directly?{{{
    #
    # Because, if the output  is longer than the screen, and  Vim uses its pager
    # to display  it, and  if we don't  go down the  output but  cancel/exit, it
    # seems  the rest  of  the code  wouldn't  be executed.   We  would have  no
    # `g:cloc_results` variable.
    #
    # We delay the display of the output to  the very end of the function, to be
    # sure the code generating `g:cloc_results` is processed.
    #}}}
    var to_display: list<string> = output_cloc

    var stats: list<list<string>> = output_cloc
        ->copy()
        ->filter((_, v: string): bool => v =~ '\d\+')
        # Why `\s\{2,}` and not simply `\s\+`?{{{
        #
        # Because there are some programming languages which contain a number in
        # their name.
        # For example,  in the source code  of `cloc`, we find  `Fortran 77` and
        # `Fortran  99`.  With  `\s\+`,  we would  split in  the  middle of  the
        # language.   With  `\s\{2,}`, it  shouldn't  occur,  unless some  weird
        # languages use more than 2 consecutive spaces in their name...
        #}}}
        ->mapnew((_, v: string): list<string> => split(v, '\s\{2,}\ze\d'))

    g:cloc_results = {}
    var keys: list<string> =<< trim END
        files
        blank
        comment
        code
    END

    for values_on_line in stats
        # `i` is going to index the `keys` list.
        # `dict` is going to store a dictionary containing the numbers of lines for a given language.
        var i: number = 0
        var dict: dict<number>

        for value in values_on_line[1 :]
            dict[keys[i]] = eval(value)
            ++i
        endfor

        g:cloc_results[values_on_line[0]] = dict
    endfor

    echo to_display->join("\n")
enddef

def unix#cloc#countLinesInFunc() #{{{1
    var filetype: string = get({vim: 'vim script', sh: 'Bourne Shell'}, &filetype, '')
    if filetype == ''
        echo 'non supported filetype'
        return
    endif
    var view: dict<number> = winsaveview()
    var g: number = 0
    var lnum1: number = 0
    var lnum2: number = 0
    # The loop handles the case where there is a nested function between us and the start of the function.{{{
    #
    #     def Func()
    #         # some code
    #         def NestedFunc()
    #             # some code
    #         enddef
    #         # we are here
    #     enddef
    #
    # The  condition of  the loop  tries  to make  sure that  our original  line
    # position is inside the found function.
    #}}}
    while (view.lnum < lnum1 || view.lnum > lnum2) && g < 9
        # if there is a nested function
        if g != 0
            # move just above (to ignore it next time we search for the body of the current function)
            normal %
            normal! k
        endif
        normal [m
        lnum1 = line('.')
        normal g%
        lnum2 = line('.')
        ++g
    endwhile
    ++lnum1
    --lnum2
    silent unix#cloc#main(lnum1, lnum2, '')
    if exists('g:cloc_results')
        var blank_cnt: number = get(g:cloc_results, filetype, {})->get('blank', 0)
        var comment_cnt: number = get(g:cloc_results, filetype, {})->get('comment', 0)
        var code_cnt: number = get(g:cloc_results, filetype, {})->get('code', 0)
        echo printf('blank: %s   comment: %s   code: %s', blank_cnt, comment_cnt, code_cnt)
    endif
    winrestview(view)
enddef

