# User specific aliases and functions
# bash customizations - georgeg
# If not running interactively, don't do anything
case $- in
    *i*) ;;
    *) return;;
esac

# Legacy #
# Only if session is interactive
#case $- in *i*)
#    # Call to login/status script
#    if [[ -f ~/.zlogin ]] ; then
#            source ~/.zlogin
#    fi
#esac

# See bash(1) for more options
# Don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# Annotate the history lines with timestamps in .bash_history
HISTTIMEFORMAT=""

# Append to the history file, don't overwrite it
shopt -s histappend

# Setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=5000
HISTFILESIZE=10000

# Check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Define a more useful default output for ps
export PS_FORMAT=euser,ruser,pid,ppid,stat,wchan,nlwp,ni,pri,%cpu,%mem,rss,stime,tty,time,cmd

# Define custom prompt string: user@host <dir> [bg_jobs|hist_#|non-0 exit/return code] $
PROMPT_COMMAND='PS1="${debian_chroot:+($debian_chroot)}\[\e[01;32m\]\u@\h\[\e[01;34m\] \w \[\e[01m\]\`if [[ \$? = "0" ]]; then echo "\\[\\e[36m\\][\\j\\\|\\!]\\[\\e[32m\\]"; else echo "\\[\\e[31m\\][\\j\\\|\\!\\\|$?]"; fi\` \$\[\e[00m\] "'

# Set PAGER appropriately
if [ -f ~/.vim/bundle/vimpager/vimpager ]; then
    export PAGER=~/.vim/bundle/vimpager/vimpager
    alias vless=~/.vim/bundle/vimpager/vimpager
    alias vcat=~/.vim/bundle/vimpager/vimcat
else
    export PAGER='less'
fi

# Configure some aliases
alias ls='ls $LS_OPTIONS --color=auto'
alias ll='ls $LS_OPTIONS -al --color=auto'
alias ssh='ssh -X'
alias upsmon="watch -n2 \"apcaccess | grep 'XONBATT\|TONBATT\|BCHARGE\|TIMELEFT\|LOADPCT\|LINEV'\""
alias dd-stat='sudo kill -USR1 $(pgrep ^dd)'
alias digl='dig +nocomments +nostats +nocmd'

# Define some helpful functions
# Watch `dd` stats
# https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
dd-stat-watch() { 
    usage () { echo "Usage: dd-stat-watch [number of seconds between updates]"; }

    case $* in 
        ''|*[!0-9]*) usage;;
        *) while [ true ]; do dd-stat; sleep "$1"; done;;
    esac
}

# Output a sorted list of all files in a given directory heirarchy by date of last modification.
ls-new() {
    usage() { echo "Usage: ls-new [search dir]"; echo "Will recursively list and sort all files in a directory heirarchy by date of last modification."; }

    # Initialize and test binary paths
    FIND="/usr/bin/find"
    SORT="/usr/bin/sort" 
    for BIN in $FIND $SORT; do 
        if ! [ -x "$(command -v $BIN)" ]; then
            echo "Error: Could not locate: $BIN" >&2 ;
            return 10;
        fi
    done

    if [ -d "$*" ]; then
        $FIND $* -printf '%M %u %g %TY %Tb %Td %p\n' | sort -t' ' -k4n -k5M -k6n
    else
        usage;
    fi
    return 0;
}

# Don't forget neofetch
# https://github.com/dylanaraps/neofetch

# Echo a funny saying at shell start
#echo Bastard Sysadmin Excuse of the Day:
#/usr/games/fortune bofh-excuses
echo

#end bash customizations
