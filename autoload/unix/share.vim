fu! unix#share#main(lnum1, lnum2) abort
    " For more info on how the web service `0x0` works, see:{{{
    "
    "     https://0x0.st/
    "     https://github.com/lachs0r/0x0
    "
    " Especially the first link.
    "}}}

    let lines = getline(a:lnum1, a:lnum2)
    sil let url = get(split(system("curl -F'file=@-' https://0x0.st", lines), '\n'), -1, '')
    "                                     │      ││{{{
    "                                     │      │└ standard input
    "                                     │      │
    "                                     │      └ force the 'content' part to be a file
    "                                     │
    "                                     └ Let curl emulate a filled-in form
    "                                       in which a user has pressed the submit button.
    "                                       This enables uploading of files.
    "}}}
    echom url
    sil call system('xdg-open ' . shellescape(url))
endfu

