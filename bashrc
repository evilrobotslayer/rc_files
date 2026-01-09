# INTERACTIVE CHECK & INITIALIZATION #
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# SET SECURE BIN PATHS #
# Define the common binary search paths
BIN_SEARCH_PATHS=("/usr/bin" "/bin" "/usr/local/bin")

# Define the commands you want to secure
# Core binaries
CMDS=(cat column cut date df du find grep gunzip ip less notify-send numfmt sed sort ssh sudo tar tail unzip uname uptime xargs)
# Validate and set variables dynamically
for cmd in "${CMDS[@]}"; do
    found=false
    for path in "${BIN_SEARCH_PATHS[@]}"; do
        # Use ${cmd//-/_} to ensure variable names are valid (e.g., replace hyphens)
        var_name="_${cmd^^}"
        var_name="${var_name//-/_}"
        if [[ -x "$path/$cmd" ]]; then
            # Create the uppercase variable (e.g., $GREP) with the first path found
            printf -v "$var_name" "%s" "$path/$cmd"
            unset var_name
            found=true
            break # Stop searching once found
        fi
    done
    [[ "$found" == false ]] && { echo "Error: Critical binary '$cmd' not found" >&2; return 10; }
done

# Optional binaries
OPTIONAL_CMDS=(7z awk bunzip2 curl dig lsof md5sum mtr netstat pgrep resolvectl sha256sum ss systemctl tmux traceroute unrar uncompress)
for cmd in "${OPTIONAL_CMDS[@]}"; do
    for path in "${BIN_SEARCH_PATHS[@]}"; do
        # Use ${cmd//-/_} to ensure variable names are valid (e.g., replace hyphens)
        var_name="_${cmd^^}"
        var_name="${var_name//-/_}"
        if [[ -x "$path/$cmd" ]]; then
            printf -v "$var_name" "%s" "$path/$cmd"
            unset var_name
            break
        fi
    done
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
    export PAGER="$_LESS"
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
alias alert='$_NOTIFY_SEND --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history 1| $_SED "s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//")"'
alias ls='ls $LS_OPTIONS --color=auto'
alias ll='ls $LS_OPTIONS -al --color=auto'
alias dd-stat='kill -USR1 $($_PGREP ^dd)'
alias digl='$_DIG +nocomments +nostats +nocmd'
alias ports='$_NETSTAT -tulanp'      # See what is listening
alias ssh='$_SSH -X'
alias upsmon="watch -n2 \"apcaccess | grep -E 'XONBATT|TONBATT|BCHARGE|TIMELEFT|LOADPCT|LINEV'\""

# Add support for ~/.bash_aliases
# See /usr/share/doc/bash-doc/examples in the bash-doc package
[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases


# FUNCTIONS #
bin-audit() {
    echo -e "\e[1;34m--- Environment Capability Audit ---\e[0m"

    # Audit Core Binaries
    echo -e "\e[1;32m[Core Utilities]\e[0m"
    for cmd in "${CMDS[@]}"; do
        var_name="_${cmd^^}"
        var_name="${var_name//-/_}"
        if [[ -n "${!var_name}" ]]; then
            printf "  %-12s : \e[32m%s\e[0m\n" "$cmd" "${!var_name}"
        else
            printf "  %-12s : \e[31mNOT FOUND\e[0m\n" "$cmd"
        fi
    done

    # Audit Optional Binaries
    echo -e "\n\e[1;34m[Optional/Portable Utilities]\e[0m"
    for cmd in "${OPTIONAL_CMDS[@]}"; do
        var_name="_${cmd^^}"
        var_name="${var_name//-/_}"
        if [[ -n "${!var_name}" ]]; then
            printf "  %-12s : \e[32m%s\e[0m\n" "$cmd" "${!var_name}"
        else
            printf "  %-12s : \e[33mNOT FOUND\e[0m\n" "$cmd"
        fi
    done
    echo
}

dd-stat-watch() {
    [[ $1 =~ ^[0-9]+$ ]] || { echo "Usage: dd-stat-watch [seconds]"; return 1; }
    while true; do dd-stat; sleep "$1"; done
}

du-top() {
    local dir="."
    local count=10
    local OPTIND

    usage() {
        echo "Usage: du-top [-n count] [directory]"
        echo "  -n  Number of entries to display (default: 10)"
        return 1
    }

    while getopts "n:h" opt; do
        case "$opt" in
            n) count="$OPTARG" ;;
            *) usage; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))
    [[ -n "$1" ]] && dir="$1"

    [[ -d "$dir" ]] || { echo "Directory not found: $dir"; return 1; }
    [[ "$count" =~ ^[0-9]+$ ]] || count=10

    echo -e "\e[1;34m--- Top $count Directories in $dir ---\e[0m"
    "$_DU" -hd 1 "$dir" 2>/dev/null | "$_SORT" -hr | "$_SED" "$((count + 1))q" | "$_COLUMN" -t
}

# Extract any archive
extract() {
    local file="$1"
    [[ -f "$file" ]] || { echo "'$1' is not a valid file"; return 1; }

    # Helper to check if optional tool exists
    _check_tool() {
        if [[ -z "$1" ]]; then
            echo "Error: Required utility for this format is not installed/found." >&2
            return 1
        fi
    }

    case "$file" in
        *.tar.bz2|*.tbz2) $_TAR xjf "$file"    ;;
        *.tar.gz|*.tgz)   $_TAR xzf "$file"    ;;
        *.tar.xz|*.txz)   $_TAR xJf "$file"    ;;
        *.tar)            $_TAR xf "$file"     ;;
        *.bz2)            _check_tool "$_BUNZIP2"    && $_BUNZIP2 "$file"    ;;
        *.rar)            _check_tool "$_UNRAR"      && $_UNRAR x "$file"    ;;
        *.gz)             $_GUNZIP "$file"     ;;
        *.zip)            $_UNZIP "$file"      ;;
        *.Z)              _check_tool "$_UNCOMPRESS" && $_UNCOMPRESS "$file" ;;
        *.7z)             _check_tool "$_7Z"         && $_7Z x "$file"       ;;
        *)                echo "ERROR: Unknown Format: '$file'"; return 1  ;;
    esac
}

# Find files modified in the last N minutes with optional depth
# Usage: find-new [minutes] [optional_depth]
find-new() {
    local mins="$1"
    local depth="$2"
    local depth_arg=""

    [[ $mins =~ ^[0-9]+$ ]] || { echo "Usage: find-new [minutes] [optional_depth]"; return 1; }

    if [[ -n "$depth" ]]; then
        [[ "$depth" =~ ^[0-9]+$ ]] || { echo "Error: Depth must be a number."; return 1; }
        depth_arg="-maxdepth $depth"
    fi

    echo "Searching for files modified in the last $mins minutes..."

    $_FIND . $depth_arg -type f -mmin -"$mins" -not -path '*/.*' -printf '%TY-%Tm-%Td | %TH:%TM:%TS | %M | %u | %g | %s | %p\n' | \
        $_SED 's/\.[0-9]* |/ |/g' | \
        $_COLUMN -t -s'|'
}

hash-check() {
    local file="$1"
    local compare_hash="$2"
    [[ -f "$file" ]] || { echo "Usage: hash-check [file] [optional_hash_to_compare]"; return 1; }

    local actual_sha=$($_SHA256SUM "$file" | "$_CUT" -d' ' -f1)
    local actual_md5=$($_MD5SUM "$file" | "$_CUT" -d' ' -f1)

    echo -e "\e[1;32mmd5:\e[0m    $actual_md5"
    echo -e "\e[1;32msha256:\e[0m $actual_sha"

    if [[ -n "$compare_hash" ]]; then
        if [[ "$actual_sha" == "$compare_hash" ]]; then
            echo -e "\e[1;32m[sha256 CONFIRMED]\e[0m"
        elif [[ "$actual_md5" == "$compare_hash" ]]; then
            echo -e "\e[1;32m[md5 CONFIRMED]\e[0m"
        else
            echo -e "\e[1;31m[HASH MISMATCH]\e[0m"
            return 1
        fi
    fi
}

log-watch() {
    local log_file="${1:-/var/log/syslog}"
    [[ -f "$log_file" ]] || { echo "Error: Log file $log_file not found."; return 1; }

    echo -e "\e[1;34m--- Watching $log_file [Ctrl+C to exit] ---\e[0m"

    # Highlight keywords: ERROR, FATAL, FAIL, CRITICAL, DENIED
    "$_TAIL" -f "$log_file" | "$_GREP" --color=always -Ei 'error|fatal|fail|critical|denied|warn|panic'
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
    "$_FIND" "$dir" -printf "$format" | "$_SORT" $sort_flags | {
        if [[ "$human_fs" == true ]]; then
            "$_NUMFMT" --to=iec --field="$size_field" --delimiter='|' --invalid=ignore
        else
            "$_CAT"
        fi
    } | "$_CUT" -d'|' -f2- | {
        if [[ "$new_ts" == true ]]; then
            "$_SED" 's/\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\)\.[0-9]*/\1/'
        else
            "$_CAT"
        fi
    } | "$_COLUMN" -t -s'|' -R "$((size_field-1))"
}

net-audit() {
    echo -e "\e[1;34m--- Network Audit ---\e[0m"

    # External
    if [[ -n "$_CURL" ]]; then
        echo -ne "\e[1;32mExternal IP:\e[0m "
        "$_CURL" -s https://ifconfig.me && echo
    fi

    # Internal / Gateway / DNS
    echo -ne "\e[1;32mLocal Interfaces:\e[0m "
    # Filters out loopback and non-ip lines
    $_IP -4 addr show | "$_GREP" -oP '(?<=inet\s)\d+(\.\d+){3}' | "$_GREP" -v '127.0.0.1'

    echo -ne "\e[1;32mDefault Gateway:\e[0m "
    if [[ -f /proc/net/route ]]; then
        local gw_hex=$("$_AWK" '$2 == "00000000" {print $3}' /proc/net/route | head -n1)
        if [[ -n "$gw_hex" ]]; then
            printf "%d.%d.%d.%d\n" 0x${gw_hex:6:2} 0x${gw_hex:4:2} 0x${gw_hex:2:2} 0x${gw_hex:0:2}
        else
            echo "None"
        fi
    else
        $_IP route | "$_GREP" default | "$_AWK" '{print $3}'
    fi

    echo -e "\e[1;32mDNS Resolvers:\e[0m "
    if [[ -f $_RESOLVECTL ]]; then
        $_RESOLVECTL status | "$_GREP" "DNS Servers"
    else
        "$_CAT" /etc/resolv.conf | "$_GREP" nameserver
    fi
}

net-trace() {
    local target="$1"
    [[ -z "$target" ]] && { echo "Usage: net-trace [host]"; return 1; }

    if [[ -n "$_MTR" ]]; then
        "$_MTR" -rw "$target"  # Report mode, wide output
    elif [[ -n "$_TRACEROUTE" ]]; then
        "$_TRACEROUTE" "$target"
    else
        echo "Error: mtr or traceroute not found." >&2
    fi
}

# Capture command output to $out_var
# Use: out2var ls -la
out2var() {
    out_var="$("$@")"
}

ports-ls() {
    echo -e "\e[1;34m--- Listening Sockets (IPv4/IPv6) ---\e[0m"
    if [[ -n "$_SS" ]]; then
        "$_SUDO" "$_SS" -tulnp | "$_TAIL" -n +2 | "$_COLUMN" -t -N "Netid,State,Recv-Q,Send-Q,Local Address:Port,Peer Address:Port,Process"
    elif [[ -n "$_LSOF" ]]; then
        "$_SUDO" "$_LSOF" -i -P -n | "$_GREP" LISTEN
    else
        echo "Error: ss or lsof required." >&2
    fi
}

# Search for text recursively in current directory with optional depth
# Usage: qgrep [search_term] [optional_depth]
qgrep() {
    local term="$1"
    local depth="$2"
    local depth_arg=""

    [[ -z "$term" ]] && { echo "Usage: qgrep [search_term] [max_depth]"; return 1; }

    # Validate and set depth if provided
    if [[ -n "$depth" ]]; then
        [[ "$depth" =~ ^[0-9]+$ ]] || { echo "Error: Depth must be a number."; return 1; }
        depth_arg="-maxdepth $depth"
    fi

    # Using -print0/xargs -0 to handle spaces/special characters in filenames safely
    $_FIND . $depth_arg -type f -not -path '*/.*' -print0 | $_XARGS -0 $_GREP -Hn --color=always "$term"
}

stats() {
    echo -e "\e[1;34m--- System Stats ---\e[0m"
    echo -e "\e[1;32mOS:\e[0m $($_UNAME -sr)"
    echo -e "\e[1;32mUptime:\e[0m $($_UPTIME -p)"
    echo -e "\e[1;32mDisk Usage:\e[0m"
    $_DF -h | $_SED -e '/^\/dev\//!d' | $_COLUMN -t -N "Filesystem,Size,Used,Avail,Use%,Mounted on"
}

tmux_dump_buffer() {
    # Generate output filename with timestamp (YYYYMMDD_HHMMSS)
    local TIMESTAMP=$($_DATE +%Y%m%d_%H%M%S)
    local OUT_FILE="tmux_buff_${TIMESTAMP}.out"

    # Display usage if input var is not a number
    [[ $1 =~ ^[0-9]+$ ]] || { echo "Usage: tmux_dump_buffer <lines>"; echo "Will dump <num_buf_lines> of the tmux buffer to tmux_buff.out"; return 1; }

    # Execute
    if $_TMUX capture-pane -S -"$1" && $_TMUX save-buffer "$OUT_FILE"; then
        echo "Saved $1 lines to $OUT_FILE"
    else
        echo "Error: Could not capture tmux buffer."
        return 1
    fi
}


# STARTUP VISUALS #
# Don't forget neofetch
# https://github.com/dylanaraps/neofetch
[[ -x /usr/bin/neofetch ]] && /usr/bin/neofetch
echo

# Echo a funny saying at shell start
if [[ -x /usr/games/fortune ]]; then
    echo Bastard Sysadmin Excuse of the Day:
    echo ==================================
    /usr/games/fortune bofh-excuses
fi
echo


#end bash customizations
