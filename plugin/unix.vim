vim9 noclear

if exists('loaded') | finish | endif
var loaded = true

#                                                     ┌ if you change the value,
#                                                     │ don't forget to put a slash at the end
const TEMPLATE_DIR: string = $HOME .. '/.vim/template/'

# TODO:
# You shouldn't call `system()`; you should `:echo` it, so that we see the exact
# error message in case of an issue (useful for example with `:Cp`).

# TODO:
# Integrate `fd(1)` (`:Fd`).  In an interactive usage, we use it much more often
# than `find(1)`, because its syntax is shorter and easier.

# Autocmds "{{{1

augroup MyUnix | au!
    au BufNewFile * MaybeReadTemplate()
                  | MaybeMakeExecutable()
augroup END

# Commands {{{1

com -bar -nargs=1 Chmod unix#chmod(<q-args>)

# Do not give the `-complete=[file|dir]` attribute to any command.{{{
#
# It makes  Vim automatically expand special  characters such as `%`,  which can
# give unexpected results, and possibly destroy valuable data.
#
# MWE:
#
#     com -complete=file -nargs=1 Cmd call Func(<args>)
#     fu Func(arg)
#         echo a:arg
#     endfu
#     Cmd 'A%B'
#     Aunix.vimB~
#
# ---
#
# In the past, we used it for these commands:
#
#     Cloc
#     Cp
#     Find
#     Locate
#     Mkdir (only one to which we gave `-complete=dir`)
#     Mv
#     SudoEdit
#}}}
# TODO: Actually, we need to give `-complete=file` to `:Mv`, otherwise `:Rename` doesn't work as expected.{{{
#
# Without, `%:h` is not expanded.
# Is there another way to expand `%:h`?
# If not, should we give back `-complete=file` to all relevant commands?
# Update: Could we use `expandcmd()` to manually expand `%:h`?
#
# ---
#
# If you use `-complete=file_in_path` instead, `%:h` is still not expanded.
# Why?
# Idk, but the issue may depend on the cwd...
#}}}
# TODO: Should we give it to harmless commands (i.e. commands which don't rename/(re)move/copy files)?
# Update: I gave it back to `:SudoEdit`; I think it should be harmless there (plus it's really useful).
com -bar -range=% -nargs=? Cloc unix#cloc#main(<line1>, <line2>, <q-args>)

com -bang -bar -nargs=1 Cp unix#cp(<q-args>, <bang>0)

com -bar -nargs=+ Find unix#grep('find', <q-args>)
# Why the bang after `com`?{{{
#
# fzf.vim installs a `:Locate` command.
#
# Usually, this is not an issue, because we configure the plugin to add a prefix
# to all the commands it installs (`Fz`).
#
# But when  we debug some issue,  we may temporarily disable  this configuration
# (by removing  `~/.vim` from the  rtp).  When  that happens, if  `vim-unix` and
# `vim-fzf` are both enabled, `E174` is raised.
#
#     E174: Command already exists: add ! to replace it~
#}}}
com! -bar -nargs=+ Locate unix#grep('locate', <q-args>)

com -bang -bar -nargs=? Mkdir unix#mkdir(<q-args>, <bang>0)

# `:Mv` lets us move the current file to any location.
# `:Rename` lets us rename the current file inside the current directory.
com -bang -bar -nargs=1 -complete=file Mv unix#move(<q-args>, <bang>0)
#                                        ┌ FIXME: what does it do?
#                                        │
com -bang -bar -nargs=1 -complete=custom,unix#renameComplete Rename Mv<bang> %:h/<args>
#                                                                            └─┤ └────┤
#                                                    directory of current file ┘      │
#                                                                     new chosen name ┘

# Usage:
# Select  some  text, and  execute  `:'<,'>Share`  to  upload the  selection  on
# `0x0.st`, or just execute `:Share` to upload the whole current file.
# TODO: Consider using this alternative site: http://ix.io/
# It seems to offer more features.
com -bar -range=% Share unix#share#main(<line1>, <line2>)

com -bang -bar -nargs=? -complete=file SudoEdit unix#sudo#edit(<q-args>, <bang>0)
com -bar SudoWrite expand('%:p')->unix#sudo#setup() | w!

# TODO:
# Are `:SudoWrite` and `:W` doing the same thing?
# Should we eliminate one of them?

# What's the effect of a bang?{{{
#
# `:Tp` deletes the current file and UNLOADS its buffer.
# Also, before  that, it loads  the alternate file if  there's one, so  that the
# current window is not (always) closed.
#
# `:Tp!` deletes the current file and RELOADS the buffer.
# As a result, we can restart the creation of a new file with the same name.
#}}}
com -bar -bang Tp unix#trash#put(<bang>0)
com -bar       Tl unix#trash#list()
#              └ Warning:{{{
#
#               It could conflict with the default `:tl[ast]` command.
#               In practice, I don't think it will, because we'll use `]T` instead.
#}}}

com -bar -nargs=0 Trr unix#trash#restore()

com -bar Wall unix#wall()

# What's the purpose of `:W`?{{{
#
# It lets us write a file for which we don't have write access to.
# This happens when we  try to edit a root file in a  Vim session started from a
# regular user.
#}}}
# What to do if I have the message `W11` or `W12`?{{{
#
# The full message looks something like this:
#
#    > W12: Warning: File "/etc/apt/sources.list" has changed and the buffer was changed in Vim as well
#    > See ":help W12" for more info.
#    > [O]K, (L)oad File:
#
# If you press `O`, the buffer will be written.
# If you press `L`, the file will be reloaded.
#
# In this particular case, whatever you answer shouldn't matter.
# The file and the buffer contain the same text.
#
# If  you've set  `'autoread'`,  there  should be  no  message,  and Vim  should
# automatically write the buffer.
#}}}
# Why `setl nomod`?{{{
#
# I don't remember what issue it solved, but I keep it because I've noticed that
# it bypasses the W12 warning.
#}}}

#               ┌ write the buffer on the standard input of a shell command (`:h w_c`)
#               │ and execute the latter
#               │
#               │   ┌ raise the rights of the `tee(1)` process so that it can write in
#               │   │ a file owned by any user
#               ├─┐ │
com -bar W exe 'w !sudo tee >/dev/null ' .. expand('%:p')->shellescape(1) | setl nomod
#                           ├────────┘              │
#                           │                       └ but write in the current file
#                           │
#                           └ don't write in the terminal

# Mappings {{{1

nno <unique> g<c-l> <cmd>Cloc<cr>
xno <unique> g<c-l> <c-\><c-n><cmd>*Cloc<cr>
nno <unique> gl <cmd>call unix#cloc#countLinesInFunc()<cr>

# Functions {{{1
def MakeExecutable() #{{{2
    var shebang: string = getline(1)->matchstr('^#!\S\+')
    if empty(shebang) || !executable('chmod')
        return
    endif
    sil system('chmod +x ' .. expand('<afile>:p:S'))
    if v:shell_error == 0
        return
    endif
    echohl ErrorMsg
    # FIXME:
    # Why is `:unsilent` needed?
    unsilent echom 'Cannot make file executable: ' .. v:shell_error
    echohl None

    # Why?{{{
    #
    # To reset `v:shell_error` to 0.
    #}}}
    # Is there another way?{{{
    #
    # `v:shell_error` is not writable.
    # So, the only way I can think of is:
    #
    #     :call system('')
    #     :!
    #}}}
    # Is it necessary?{{{
    #
    # I don't know.
    #
    # Usually,  plugins'  authors don't  seem  to  care about  resetting
    # `v:shell_error`:
    #
    #     :vim /v:shell_error/gj ~/.vim/**/*.vim ~/.vim/**/vim.snippets $MYVIMRC
    #
    # But, better be safe than sorry.
    #
    # Also, have a look at `:h todo`, and search for `v:shell_error`.
    # A patch was submitted in 2016 to make the variable writable.
    # So, I'm not alone thinking it would  be useful to be able to write
    # this variable.
    #}}}
    system('')
enddef

def MaybeMakeExecutable() #{{{2
    au BufWritePost <buffer> ++once MakeExecutable()
enddef

def MaybeReadTemplate() #{{{2
    # For an example of template file, have a look at:
    #
    #     /etc/init.d/skeleton

    # Get all the filetypes for which we have a template.
    var filetypes: list<string> = glob(TEMPLATE_DIR .. 'by_filetype/*', false, true)
        ->map((_, v) => fnamemodify(v, ':t:r'))

    if index(filetypes, &ft) >= 0
    && filereadable(TEMPLATE_DIR .. 'by_filetype/' .. &ft .. '.txt')
        #    ┌ don't use the template file as the alternate file for the current window{{{
        #    │ keep the current one
        #    │
        #    │ Note that `:keepalt` is not useful when you read the output of an
        #    │ external command (`:r !cmd`).
        #    │}}}
        exe 'keepalt read ' .. fnameescape(TEMPLATE_DIR .. 'by_filetype/' .. &ft .. '.txt')
        keepj :1d _

    elseif expand('<afile>:p') =~ '.*/compiler/[^/]*\.vim'
    && filereadable(TEMPLATE_DIR .. 'by_name/compiler.txt')
        setline(1, ['let current_compiler = ' .. expand('<afile>:p:t:r')->string(), ''])
        exe 'keepalt :2read ' .. TEMPLATE_DIR .. 'by_name/compiler.txt'
        # If our compiler  is in `~/.vim/compiler`, we want to  skip the default
        # compilers in `$VIMRUNTIME/compiler`.
        # In this case, we need 'current_compiler' to be set.

    elseif expand('<afile>:p') =~ '.*/filetype\.vim'
    && filereadable(TEMPLATE_DIR .. 'by_name/filetype.txt')
        exe 'keepalt read ' .. TEMPLATE_DIR .. 'by_name/filetype.txt'
        keepj :1d _

    elseif expand('<afile>:p') =~ '.*/scripts\.vim'
    && filereadable(TEMPLATE_DIR .. 'by_name/scripts.txt')
        exe 'keepalt read ' .. TEMPLATE_DIR .. 'by_name/scripts.txt'
        keepj :1d _

    # useful to get a mini `tmux.conf` when debugging tmux
    elseif expand('<afile>:t') == 'tmux.conf'
        var lines: list<string> =<< trim END
            set -g prefix M-space
            set -g status-keys emacs
            set -s history-file "$HOME/.config/tmux/command_history"
            set -g history-limit 50000
            bind -T root M-l next
            bind -T root M-h prev
            bind -T root ¹ next
            bind -T root ² prev
            bind -T copy-mode-vi v send -X begin-selection
            bind -T copy-mode-vi V send -X select-line
            bind -T root M-s copy-mode
            bind M-space last-pane
            bind | splitw  -h -c ''#{pane_current_path}''
            bind _ splitw -fv -c ''#{pane_current_path}''
            bind h select-pane -L
            bind j select-pane -D
            bind k select-pane -U
            bind l select-pane -R
            bind C-p paste-buffer -p
            bind p choose-buffer -Z "paste-buffer -p -b ''%%''"
        END
        setline(1, lines)

    elseif expand('<afile>:p:h') == '' .. $HOME .. '/.zsh/my-completions'
        setline(1, ['#compdef ' .. expand('<afile>:t')[1 :], '', ''])
    endif
enddef

