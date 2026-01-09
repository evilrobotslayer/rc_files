# INTERACTIVE CHECK & INITIALIZATION #
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# SET GLOBAL VARIABLES #
# This may need to be set appropriately
BIN_path="/usr/bin"

# Define the commands you want to secure
CMDS=(cat column cut find grep less numfmt sed sort tmux ssh awk gunzip unzip tar)

# Validate and set variables dynamically
for cmd in "${CMDS[@]}"; do
    path="$BIN_path/$cmd"
    if [[ -x "$path" ]]; then
        # This creates variables like $CAT, $GREP, etc.
        printf -v "${cmd^^}" "%s" "$path"
    else
        echo "Error: Critical binary not found: $path" >&2
        return 10
    fi
done


# HISTORY SETTINGS #
# See bash(1) for more options
# ignoreboth = ignoredups + ignorespace
HISTCONTROL="ignoreboth:erasedups"
HISTIGNORE="ls:ll:cd:pwd:bg:fg:history"
# Annotate the history lines with timestamps in .bash_history
HISTTIMEFORMAT="%F %T: "
HISTSIZE=25000
HISTFILESIZE=100000
# Append to the history file, don't overwrite it
# Check the window size after each command and update LINES and COLUMNS
shopt -s histappend checkwinsize


# ENVIRONMENT VARIABLES #
# Set CLI editing mode to vi and allow mode-prompt indicator
set -o vi

# Define a more useful default output for ps
export PS_FORMAT=euser,ruser,pid,ppid,stat,wchan,nlwp,ni,pri,%cpu,%mem,rss,stime,tty,time,cmd

# Set PAGER
if [[ -f ~/.vim/bundle/vimpager/vimpager ]]; then
    export PAGER=~/.vim/bundle/vimpager/vimpager
    alias vless="$PAGER"
    alias vcat=~/.vim/bundle/vimpager/vimcat
else
    export PAGER="$LESS"
fi


# SET PROMPT #
define_prompt() {
    local EXIT="$?"
    # Sync history
    history -a; history -c; history -r

    # Use tput for cleaner color definitions (more portable)
    local G='\[\e[01;32m\]' B='\[\e[01;34m\]' C='\[\e[36m\]' 
    local R='\[\e[31m\]' W='\[\e[00m\]' BOLD='\[\e[01m\]'

    # Check return/exit status
    if (( EXIT == 0 )); then
        local STATUS="${C}[\j| \! ]${G}"
    else
        local STATUS="${R}[\j|\!|$EXIT]"
    fi

    # Build prompt
    # The \f is the mode indicator placeholder provided by 'show-mode-in-prompt'
    PS1="${debian_chroot:+($debian_chroot)}${G}\u@\h${B} \w ${BOLD}${STATUS} \$${W} "
}
PROMPT_COMMAND=define_prompt


# BASH COMPLETION #
# Enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).

if ! shopt -oq posix; then
    [[ -f /usr/share/bash-completion/bash_completion ]] && . /usr/share/bash-completion/bash_completion
    [[ -f /etc/bash_completion ]] && . /etc/bash_completion
fi


# ALIASES #
# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history 1|sed "s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//")"'
alias ls='ls $LS_OPTIONS --color=auto'
alias ll='ls $LS_OPTIONS -al --color=auto'
alias dd-stat='sudo kill -USR1 $(pgrep ^dd)'
alias digl='dig +nocomments +nostats +nocmd'
alias ports='netstat -tulanp'      # See what is listening
alias ssh='ssh -X'
alias upsmon="watch -n2 \"apcaccess | grep -E 'XONBATT|TONBATT|BCHARGE|TIMELEFT|LOADPCT|LINEV'\""

# Add support for ~/.bash_aliases
# See /usr/share/doc/bash-doc/examples in the bash-doc package
[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases


# FUNCTIONS #
dd-stat-watch() {
    [[ $1 =~ ^[0-9]+$ ]] || { echo "Usage: dd-stat-watch [seconds]"; return 1; }
    while true; do dd-stat; sleep "$1"; done
}

# Extract any archive
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2) tar xjf "$1"    ;;
            *.tar.gz)  tar xzf "$1"    ;;
            *.bz2)     bunzip2 "$1"    ;;
            *.rar)     unrar x "$1"     ;;
            *.gz)      gunzip "$1"     ;;
            *.tar)     tar xf "$1"     ;;
            *.tbz2)    tar xjf "$1"    ;;
            *.tgz)     tar xzf "$1"    ;;
            *.zip)     unzip "$1"      ;;
            *.Z)       uncompress "$1" ;;
            *)         echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

ls-new() {
    local dir="."
    local human_fs=false
    local new_ts=false
    local reverse=false
    local OPTIND  # Required: resets getopts index if function is called multiple times

    usage() {
        echo "Usage: ls-new [-h] [-t] [directory]"
        echo "  -h  Adds human-readable file sizes"
        echo "  -t  Show file timestamp (format: YYYY-MM-DD HH:MM:SS)"
        echo "  -r  Reverse sort order (oldest first)"
        echo "Recursively lists and sorts all files by date of last modification."
        return 1
    }

    while getopts "htr" opt; do
        case "$opt" in
            h) human_fs=true ;;
            t) new_ts=true ;;
            r) reverse=true ;;
            *) usage; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))        # Remove parsed options from arguments
    [[ -n "$1" ]] && dir="$1"    # Remaining argument is the directory

    [[ -d "$dir" ]] || { echo "Directory not found: $dir"; usage; return 1; }

    # Sort logic:
    local sort_flags='-n'
    [[ "$reverse" == true ]]  && sort_flags="-nr"

    # Format Logic:
    # Default format: [Epoch]|Perms|User|Group|Size|Date|Path
    local format='%T@|%M|%u|%g|%s|%TY %Tb %Td|%p\n'
    local size_field=5

    if [[ "$new_ts" == true ]]; then
        # Format: [Epoch]|Date|HH:MM:SS|Perms|User|Group|Size|Path
        format='%T@|%TY-%Tm-%Td|%TH:%TM:%TS|%M|%u|%g|%s|%p\n'
        size_field=7
    fi

    # Execute
    # We pipe everything into a group { ...; } to keep the stream alive
    "$FIND" "$dir" -printf "$format" | "$SORT" $sort_flags | {
        if [[ "$human_fs" == true ]]; then
            "$NUMFMT" --to=iec --field="$size_field" --delimiter='|' --invalid=ignore
        else
            "$CAT"
        fi
    } | "$CUT" -d'|' -f2- | {
        if [[ "$new_ts" == true ]]; then
            "$SED" 's/\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\.[0-9]*/\1/'
        else
            "$CAT"
        fi
    } | "$COLUMN" -t -s'|' -R "$((size_field-1))"
}

# Capture command output to $out_var
# Use: out2var ls -la
out2var() {
    out_var="$("$@")"
}

# Search for text recursively in current directory with optional depth
# Usage: qgrep [search_term] [max_depth]
qgrep() {
    local term="$1"
    local depth="$2"

    [[ -z "$term" ]] && { echo "Usage: qgrep [search_term] [optional_depth]"; return 1; }

    # If a depth is provided, build the depth argument
    local depth_arg=""
    if [[ -n "$depth" ]]; then
        if [[ "$depth" =~ ^[0-9]+$ ]]; then
            depth_arg="-maxdepth $depth"
        else
            echo "Error: Depth must be a number."
            return 1
        fi
    fi

    # Execute find with maxdepth (if set) and pipe to grep
    # Using -print0 and xargs -0 to safely handle spaces in filenames
    $FIND . $depth_arg -type f -not -path '*/.*' -print0 | xargs -0 $GREP -Hn --color=always "$term"
}

stats() {
    echo -e "\e[1;34m--- System Stats ---\e[0m"
    echo -e "\e[1;32mOS:\e[0m $(uname -sr)"
    echo -e "\e[1;32mUptime:\e[0m $(uptime -p)"
    echo -e "\e[1;32mDisk Usage:\e[0m"
    df -h | $GREP '^/dev/' | $COLUMN -t
}

tmux_dump_buffer() {
    # Generate output filename with timestamp (YYYYMMDD_HHMMSS)
    local TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local OUT_FILE="tmux_buff_${TIMESTAMP}.out"

    # Display usage if input var is not a number
    [[ $1 =~ ^[0-9]+$ ]] || { echo "Usage: tmux_dump_buffer <lines>"; echo "Will dump <num_buf_lines> of the tmux buffer to tmux_buff.out"; return 1; }

    # Execute
    if $TMUX capture-pane -S -"$1" && $TMUX save-buffer "$OUT_FILE"; then
        echo "Saved $1 lines to $OUT_FILE"
    else
        echo "Error: Could not capture tmux buffer."
        return 1
    fi
}


# STARTUP VISUALS #
# Don't forget neofetch
# https://github.com/dylanaraps/neofetch
[[ -x /usr/bin/neofetch ]] && neofetch
echo

# Echo a funny saying at shell start
#echo Bastard Sysadmin Excuse of the Day:
#echo ==================================
#/usr/games/fortune bofh-excuses
echo


#end bash customizations
