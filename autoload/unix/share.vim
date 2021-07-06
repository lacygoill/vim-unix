vim9script noclear

def unix#share#main(lnum1: number, lnum2: number)
    # For more info on how the web service `0x0` works, see:{{{
    #
    #     https://0x0.st/
    #     https://github.com/lachs0r/0x0
    #
    # Especially the first link.
    #}}}

    var lines: list<string> = getline(lnum1, lnum2)
    silent var url: string = system(
        "curl -F'file=@-' https://0x0.st", lines)->split('\n')->get(-1, '')
    #          │      ││{{{
    #          │      │└ standard input
    #          │      │
    #          │      └ force the 'content' part to be a file
    #          │
    #          └ Let curl emulate a filled-in form
    #            in which a user has pressed the submit button.
    #            This enables uploading of files.
    #}}}
    echomsg url
    silent system('xdg-open ' .. shellescape(url))
enddef

