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
# Also ignore common commands
HISTCONTROL="ignoreboth:erasedups"
HISTIGNORE="ls:ll:cd:pwd:bg:fg:history"

# Annotate the history lines with timestamps in .bash_history
HISTTIMEFORMAT="%F %T: "

# Append to the history file, don't overwrite it
shopt -s histappend

# Setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=25000
HISTFILESIZE=100000

# Check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Define a more useful default output for ps
export PS_FORMAT=euser,ruser,pid,ppid,stat,wchan,nlwp,ni,pri,%cpu,%mem,rss,stime,tty,time,cmd

# Define custom prompt string: user@host <dir> [bg_jobs|hist_#|non-0 exit/return code] $
# Legacy version
# PROMPT_COMMAND='PS1="${debian_chroot:+($debian_chroot)}\[\e[01;32m\]\u@\h\[\e[01;34m\] \w \[\e[01m\]\`if [[ \$? = "0" ]]; then echo "\\[\\e[36m\\][\\j\\\|\\!]\\[\\e[32m\\]"; else echo "\\[\\e[31m\\][\\j\\\|\\!\\\|$?]"; fi\` \$\[\e[00m\] "'
# Define the prompt logic in a function
define_prompt() {
    local EXIT="$?"
    # Sync history
    history -a; history -c; history -r

    # Define colors
    local GREEN='\[\e[01;32m\]'
    local BLUE='\[\e[01;34m\]'
    local CYAN='\[\e[36m\]'
    local RED='\[\e[31m\]'
    local RESET='\[\e[00m\]'
    local BOLD='\[\e[01m\]'

    # Build the status part
    if [ "$EXIT" -eq 0 ]; then
        local STATUS="${CYAN}[\j| \! ]${GREEN}"
    else
        local STATUS="${RED}[\j|\!|$EXIT]"
    fi
    PS1="${debian_chroot:+($debian_chroot)}${GREEN}\u@\h${BLUE} \w ${BOLD}${STATUS} \$${RESET} "
}

PROMPT_COMMAND=define_prompt

# Set CLI editing mode to vi
set -o vi

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

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal ||
echo error)" "$(history 1|sed '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Define some helpful functions
# Watch `dd` stats
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

# Capture command output to $out_var
out2var() {
    out_var="$($*)";
}

tmux_dump_buffer() {
  usage () { echo "Usage: tmux_dump_buffer <num_buf_lines>"; echo "Will dump <num_buf_lines> of the tmux buffer to tmux_buff.out"; }

  if [ "$#" -ne 1 ]; then
      echo "This function only takes 1 argument.";
      echo "Args Provided: $#";
      echo "";
      usage;
      return 2;
  fi

  tmux capture-pane -S -"$*"; tmux save-buffer tmux_buff.out
  return 0
}

# Don't forget neofetch
# https://github.com/dylanaraps/neofetch
if [ -f /usr/bin/neofetch ]; then echo; neofetch; fi

# Echo a funny saying at shell start
#echo Bastard Sysadmin Excuse of the Day:
#/usr/games/fortune bofh-excuses
echo

#end bash customizations
