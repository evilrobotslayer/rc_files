#io INTERACTIVE CHECK & INITIALIZATION #
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Ensure TTY is set
[[ -z "$TTY" ]] && TTY=$(tty)
tty_suffix=${TTY//\//_}


# SET SECURE BIN PATHS #
_init_security() {
    # Define the common binary search paths
    _BIN_SEARCH_PATHS=("/usr/bin" "/bin" "/usr/local/bin")
    # Security Check: Ensure path is root-owned and not world-writable (o-w)
    for i in "${!_BIN_SEARCH_PATHS[@]}"; do
        local path="${_BIN_SEARCH_PATHS[i]}"
        local stats
        stats=$(/usr/bin/stat -c "%u %a" "$path" 2>/dev/null)
        # Remove and continue loop if path doesn't exist
        [[ -z "$stats" ]] && { unset "_BIN_SEARCH_PATHS[$i]"; continue; }

        # Split $stats into two variables for owner and perms
        read -r owner perms <<< "$stats"
        
        # Check: Not root-owned OR world-writable
        # 0002 is the bitmask for world-writable
        # 0020 is the bitmask for group-writable
        # 8#$mode forces Bash to interpret the variable as an octal number
        if [[ "$owner" != "0" ]] || (( (8#$perms & 0002) != 0 )); then
            echo -e "\e[1;33mWarning: Removing insecure path \e[1;31m$path\e[0m" >&2
            unset "_BIN_SEARCH_PATHS[$i]"
        fi
    done
    # Re-index to collapse holes
    _BIN_SEARCH_PATHS=("${_BIN_SEARCH_PATHS[@]}")

    # Define the commands you want to secure
    # Combined List for initial path validation
    CMDS=(basename cat clear column cut date df dmesg du find grep gunzip head ip join kill ls less more notify-send numfmt ps readlink rm sed sleep sort ssh stat sudo tar tail tput tr unzip uname uptime watch xargs)
    OPTIONAL_CMDS=(7z apt apt-get apt-cache awk bunzip2 curl dig dnf expac lsof md5sum mtr netstat nmtui pacman pgrep resolvectl rpm sha256sum ss systemctl tmux traceroute unrar uncompress yum)

    # Single pass to map binaries to variables and aliases
    for cmd in "${CMDS[@]}" "${OPTIONAL_CMDS[@]}"; do
        local found=false
        local var_name
        for path in "${_BIN_SEARCH_PATHS[@]}"; do
            if [[ -x "$path/$cmd" ]]; then
                var_name="_${cmd^^}"
                var_name="${var_name//-/_}"
                printf -v "$var_name" "%s" "$path/$cmd"
                alias "$cmd"="${!var_name}"
                found=true
                break
            fi
        done
        # Only exit on missing Core CMDS
        if [[ "$found" == false ]]; then
            for core in "${CMDS[@]}"; do
                if [[ "$cmd" == "$core" ]]; then
                    echo -e "\e[1;31mError: Critical binary '\e[1;33m$cmd\e[1;31m' not found\e[0m" >&2
                fi
            done
        fi
    done
}
_init_security


# CLEANUP OLD SESSION STATS #
$_RM -f /dev/shm/bash_stats_"${tty_suffix}"_* 2>/dev/null


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

# Define common colors
# Initialize Tput Capabilities
if [[ -t 1 ]]; then
    _T_RESET=$($_TPUT sgr0)
    _T_BOLD=$($_TPUT bold)
    _T_RED=$($_TPUT setaf 1)
    _T_GRN=$($_TPUT setaf 2)
    _T_YLW=$($_TPUT setaf 3)
    _T_BLU=$($_TPUT setaf 4)
    _T_CYN=$($_TPUT setaf 6)
    _T_REV=$($_TPUT smso) # Standout/Reverse mode
fi

# Exporting for subshells and consistency
export _CLR_B_GRN="$_T_BOLD$_T_GRN"     # Nominal / Success
export _CLR_GRN="$_T_GRN"               # Nominal / Success
export _CLR_B_YLW="$_T_BOLD$_T_YLW"     # Warning / Transition
export _CLR_YLW="$_T_YLW"               # Warning / Transition
export _CLR_B_RED="$_T_BOLD$_T_RED"     # Critical / Error
export _CLR_RED="$_T_RED"               # Critical / Error
export _CLR_B_BLU="$_T_BOLD$_T_BLU"     # Headers / Info
export _CLR_B_CYN="$_T_CYN"             # Secondary Info
export _CLR_BOLD="$_T_BOLD"             # High Emphasis
export _CLR_R_BG="$_T_REV$_T_RED"       # Alert (White on Red)
export _CLR_NC="$_T_RESET"              # No Color (Reset)

# ANSI Color Codes (High Intensity/Bold)
#export _CLR_B_GRN='\e[1;32m'  # Nominal / Success
#export _CLR_GRN='\e[32m'      # Nominal / Success
#export _CLR_B_YLW='\e[1;33m'  # Warning / Transition
#export _CLR_YLW='\e[33m'      # Warning / Transition
#export _CLR_B_RED='\e[1;31m'  # Critical / Error
#export _CLR_RED='\e[31m'      # Critical / Error
#export _CLR_B_BLU='\e[1;34m'  # Headers / Info
#export _CLR_B_CYN='\e[36m'    # Secondary Info
#export _CLR_BOLD='\e[1m'      # High Emphasis
#export _CLR_R_BG='\e[41;37m'  # Alert (White on Red)
#export _CLR_NC='\e[0m'        # No Color (Reset)

# AWK-compatible versions (since AWK needs literal escape characters)
export _AWK_B_GRN='\033[1;32m'
export _AWK_B_YLW='\033[1;33m'
export _AWK_B_RED='\033[1;31m'
export _AWK_NC='\033[0m'


# SET PROMPT #
_define_prompt() {
    local EXIT="$?"
    # Sync history
    history -a; history -c; history -r

    # Use tput for cleaner color definitions (more portable)
    local G="$_CLR_B_GRN" B="$_CLR_B_BLU" C="$_CLR_B_CYN"
    local R="$_CLR_B_RED" W="$_CLR_NC" BOLD="$_CLR_BOLD"

    # Check return/exit status and wrap internal color codes in \[ \]
    if (( EXIT == 0 )); then
        local STATUS="\[${C}\][\j| \! ]\[${G}\]"
    else
        local STATUS="\[${R}\][\j|\!|$EXIT]"
    fi

    # Build prompt with non-printing wrappers around all color variables
    PS1="${debian_chroot:+($debian_chroot)}\[${G}\]\u@\h\[${B}\] \w \[${BOLD}\]${STATUS} \[${BOLD}\]\$\[${W}\] "
}
PROMPT_COMMAND=_define_prompt


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
alias ls='$_LS $LS_OPTIONS --color=auto'
alias ll='$_LS $LS_OPTIONS -al --color=auto'
alias dd-stat='$_KILL -USR1 $($_PGREP ^dd)'
alias digl='$_DIG +nocomments +nostats +nocmd'
alias ports='$_NETSTAT -tulanp'      # See what is listening
alias ssh='$_SSH -X'
alias upsmon="$_WATCH -n2 \"apcaccess | $_GREP -E 'XONBATT|TONBATT|BCHARGE|TIMELEFT|LOADPCT|LINEV'\""

# Add support for ~/.bash_aliases
# See /usr/share/doc/bash-doc/examples in the bash-doc package
[[ -f ~/.bash_aliases ]] && . ~/.bash_aliases


# FUNCTIONS #
# Helper function to aid in rendering utility functions in a loop
_loop_render() {
    local interval="$1"
    local render_func="$2"
    shift 2

    # Global cleanup to ensure cursor restoration
    _restore_cursor() {
        $_TPUT cnorm
        stty echo
    }

    if [[ "$interval" =~ ^[0-9]+$ ]]; then
        # Execute the loop in a subshell to isolate signal handling
        (
            # The EXIT trap inside the subshell triggers on any termination
            trap '_restore_cursor; exit' SIGINT SIGTERM EXIT
            # Hide cursor for cleaner dashboard feel
            $_TPUT civis 
            while true; do
                "$render_func" "$@"
                $_SLEEP "$interval"
            done
       )
    else
        # For non-looping calls, we still want cursor protection for streaming functions
        (
            trap '_restore_cursor' EXIT
            $_TPUT civis
            "$render_func" "$@"
        )    
    fi
}

bin-audit() {
    : "Audit environment for required and optional binaries and mapping status"
    local cmd var_name found core func_list func bin_path found_collision
    echo -e "${_CLR_B_BLU}--- Environment Capability Audit ---${_CLR_NC}"

    # Audit Core Binaries
    echo -e "${_CLR_B_GRN}[Core Utilities]${_CLR_NC}"
    for cmd in "${CMDS[@]}"; do
        var_name="_${cmd^^}"
        var_name="${var_name//-/_}"
        if [[ -n "${!var_name}" ]]; then
            printf "  %-12s : ${_CLR_GRN}%s${_CLR_NC}\n" "$cmd" "${!var_name}"
        else
            printf "  %-12s : ${_CLR_RED}NOT FOUND${_CLR_NC}\n" "$cmd"
        fi
    done

    # Audit Optional Binaries
    echo -e "\n${_CLR_B_BLU}[Optional/Portable Utilities]${_CLR_NC}"
    for cmd in "${OPTIONAL_CMDS[@]}"; do
        var_name="_${cmd^^}"
        var_name="${var_name//-/_}"
        if [[ -n "${!var_name}" ]]; then
            printf "  %-12s : ${_CLR_GRN}%s${_CLR_NC}\n" "$cmd" "${!var_name}"
        else
            printf "  %-12s : ${_CLR_YLW}NOT FOUND${_CLR_NC}\n" "$cmd"
        fi
    done

    # Shadowing Audit
    echo -e "\n${_CLR_B_YLW}[Command Shadowing]${_CLR_NC}"
    func_list=$(declare -F | $_AWK '{print $3}' | $_GREP -vE '^(_|usage|quote|dequote|command_not_found)')
    found_collision=false

    for func in $func_list; do
        bin_path=$(type -ap "$func" | $_HEAD -n 1)
        if [[ -n "$bin_path" ]]; then
            printf "  %-12s : ${_CLR_RED}Warning: Masks %s${_CLR_NC}\n" "$func" "$bin_path"
            found_collision=true
        fi
    done
    [[ "$found_collision" == false ]] && echo "  No binary collisions detected."
    echo
}

dd-stat-watch() {
    : "Monitor dd progress by sending USR1 signals at specified intervals"
    [[ $1 =~ ^[0-9]+$ ]] || { echo "Usage: dd-stat-watch [seconds]"; return 1; }
    while true; do dd-stat; $_SLEEP "$1"; done
}

du-top() {
    : "Display top N largest directories in a given path (default 10)"
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

    echo -e "${_CLR_B_BLU}--- Top $count Directories in $dir ---${_CLR_NC}"
    "$_DU" -x -hd 1 "$dir" 2>/dev/null | "$_SORT" -hr | "$_SED" "$((count + 1))q" | "$_COLUMN" -t
}

extract() {
    : "Universal archive expansion utility for common compression formats"
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

# Usage: find-new [minutes] [optional_depth]
find-new() {
    : "Locate files modified within N minutes with optional depth"
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
    : "Calculate SHA256/MD5 checksums and verify if checksum string is provided"
    local file="$1"
    local compare_hash="$2"
    [[ -f "$file" ]] || { echo "Usage: hash-check [file] [optional_hash_to_compare]"; return 1; }

    local actual_sha=$($_SHA256SUM "$file" | "$_CUT" -d' ' -f1)
    local actual_md5=$($_MD5SUM "$file" | "$_CUT" -d' ' -f1)

    echo -e "${_CLR_B_GRN}md5:${_CLR_NC}    $actual_md5"
    echo -e "${_CLR_B_GRN}sha256:${_CLR_NC} $actual_sha"

    if [[ -n "$compare_hash" ]]; then
        if [[ "$actual_sha" == "$compare_hash" ]]; then
            echo -e "${_CLR_B_GRN}[sha256 CONFIRMED]${_CLR_NC}"
        elif [[ "$actual_md5" == "$compare_hash" ]]; then
            echo -e "${_CLR_B_GRN}[md5 CONFIRMED]${_CLR_NC}"
        else
            echo -e "${_CLR_B_RED}[HASH MISMATCH]${_CLR_NC}"
            return 1
        fi
    fi
}

io-audit() {
    : "Filesystem usage and real-time Disk IOPS"
    local interval="$1"
    local tty_suffix=${TTY//\//_}
    local iops_file="/dev/shm/bash_stats_${tty_suffix}_iops"

    _render_io() {
        local now
        printf -v now '%(%s)T' -1

        [[ -n "$interval" ]] && $_CLEAR
        echo -e "${_CLR_B_GRN}Storage Monitoring${_CLR_NC} $([[ -n "$interval" ]] && echo "(Interval: ${interval}s)")"

        local stats_snapshot=$($_CAT /proc/diskstats)
        
        # Capture columns directly: dev_node=$1, fs_size=$2, fs_perc=$5, fs_mnt=$6
        while read -r dev_node fs_size _ _ fs_perc fs_mnt; do
            # Filter for relevant storage types
            [[ "$dev_node" =~ ^(/dev/|zroot|pool) ]] || continue

            local perc_val="${fs_perc%%%}"
            local block_dev="${dev_node##*/}"

            # Standard block device resolution
            if [[ -d "/sys/class/block/$block_dev/slaves" ]]; then
                local slave=$($_LS "/sys/class/block/$block_dev/slaves" | $_HEAD -n1)
                [[ -n "$slave" ]] && block_dev="$slave"
            fi

            local dev_stats=$($_GREP -w "$block_dev" <<< "$stats_snapshot")
            # Mapping /proc/diskstats: 4=riops, 6=rsect, 8=wiops, 10=wsect
            # We use '_' to skip irrelevant indices
            read -r _ _ _ riops_now _ rsect_now _ wiops_now _ wsect_now _ <<< "$dev_stats"

            local s_size=$($_CAT "/sys/class/block/$block_dev/queue/hw_sector_size" 2>/dev/null || echo 512)

            local r_speed="0.00" w_speed="0.00" r_iops="0" w_iops="0"
            if [[ -f "$iops_file" ]]; then
                local last_data=$($_GREP "^$block_dev " "$iops_file")
                if [[ -n "$last_data" ]]; then
                    read -r _ last_t last_ri last_rs last_wi last_ws <<< "$last_data"
                    local t_diff=$((now - last_t))
                    if (( t_diff > 0 )); then
                        # Pure Bash integer math for KB/s
                        r_speed=$(( (riops_now - last_ri) * s_size / 1024 / t_diff ))
                        w_speed=$(( (wiops_now - last_wi) * s_size / 1024 / t_diff ))
                        r_iops=$(( (riops_now - last_ri) / t_diff ))
                        w_iops=$(( (wiops_now - last_wi) / t_diff ))
                    fi
                fi
            fi

            # Update cache
            $_SED -i "/^$block_dev /d" "$iops_file" 2>/dev/null
            echo "$block_dev $now $riops_now $rsect_now $wiops_now $wsect_now" >> "$iops_file"

            # Color & Bar Logic
            local BAR_COLOR="$_CLR_B_GRN"
            (( perc_val > 50 )) && BAR_COLOR="$_CLR_B_YLW"
            (( perc_val > 85 )) && BAR_COLOR="$_CLR_B_RED"

            # Use fixed 20-character width for the total bar area
            local f=$((perc_val / 5))
            local e=$((20 - f))

            # Ensure strings are generated cleanly
            local bar="" spc=""
            [[ $f -gt 0 ]] && printf -v bar "%${f}s" ""; bar=${bar// /#}
            [[ $e -gt 0 ]] && printf -v spc "%${e}s" ""; spc=${spc// /-}

            local threshold=90; [[ "$fs_mnt" == "/" || "$fs_mnt" == "/boot"* ]] && threshold=80
            local alert=" "; [[ $perc_val -ge $threshold ]] && alert="${_CLR_R_BG}!${_CLR_NC}"

            # Use specific width formatting in the final printf to lock the alignment
            printf "  %b %-15s [%s] [%b%-s%b%-s] %3d%% | R:%5s KB/s (%s iops) | W:%5s KB/s (%s iops)\n" \
              "$alert" "$fs_mnt" "$fs_size" "$BAR_COLOR" "$bar" "$_CLR_NC" "$spc" "$perc_val" "$r_speed" "$r_iops" "$w_speed" "$w_iops"
        done < <($_DF -h)
    }
    _loop_render "$interval" _render_io
}

ip-local() {
    : "Mapping of network interfaces to IP, MAC, and Status"
    local show_header=true
    local OPTIND=1
    while getopts "n" opt; do
        case "$opt" in
            n) show_header=false ;;
            *) return 1 ;;
        esac
    done
    shift $((OPTIND-1))

    [[ "$show_header" == true ]] && echo -e "${_CLR_B_GRN}Interface IP/MAC Mapping:${_CLR_NC}"

    local link_info=$($_IP -brief link show)
    
    $_IP -brief addr show | $_AWK -v links="$link_info" '
    BEGIN {
        n = split(links, a, "\n")
        for (i=1; i<=n; i++) {
            split(a[i], b); meta[b[1]] = b[2] "  " b[3]
        }
    }
    $1 != "lo" {
        printf "  %-12s %-18s %s\n", $1":", $3, meta[$1]
    }'
}

log-tail() {
    : "Aggregate system errors with follow support"
    
    local follow=false
    local count=10
    local OPTIND
    
    while getopts "fu:" opt; do
        case "$opt" in
            f) follow=true ;;
            u) usage; return 0 ;;
        esac
    done
    shift $((OPTIND - 1))
    
    [[ -n "$1" ]] && count="$1"

    echo -e "${_CLR_B_RED}System Errors (Priority 0-3):${_CLR_NC}"
    
    if [[ -n "$_SYSTEMCTL" ]]; then
        local args=("-p" "0..3" "-n" "$count" "--no-hostname" "--no-pager")
        [[ "$follow" == true ]] && args+=("-f")
        journalctl "${args[@]}"
    else
        # Traditional fallback logic
        local log_file=""
        [[ -f /var/log/syslog ]] && log_file="/var/log/syslog"
        [[ -f /var/log/messages ]] && log_file="/var/log/messages"
        
        if [[ -n "$log_file" ]]; then
            if [[ "$follow" == true ]]; then
                $_TAIL -f "$log_file" | $_GREP -iE "error|fail|critical"
            else
                $_GREP -iE "error|fail|critical" "$log_file" | $_TAIL -n "$count"
            fi
        fi
    fi
}

log-watch() {
    : "Stream log files with high-visibility color highlighting; -a flag shows all lines"
    local log_file=""
    local show_all=false
    local OPTIND=1

    # Parse options
    while getopts "a" opt; do
        case "$opt" in
            a) show_all=true ;;
            *) echo "Usage: log-watch [-a] [file]"; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    log_file="${1:-/var/log/syslog}"
    
    [[ -f "$log_file" ]] || { 
        echo -e "${_CLR_B_RED}Error:${_CLR_NC} Log file $log_file not found."
        return 1 
    }

    _render_log() {
        local file="$1"
        local mode="$2"
        echo -e "${_CLR_B_BLU}--- Watching $file [Ctrl+C to exit] ---${_CLR_NC}"

        # Define the regex for critical keywords
        local regex='error|fatal|fail|critical|denied|warn|panic' 

        if [[ "$mode" == "true" ]]; then
            # Use GREP in "pass-through" mode: match the regex OR match the start of every line
            # This ensures all lines are printed, but only the regex keywords are colored
            "$_TAIL" -f "$file" | "$_GREP" --color=always -Ei "$regex|$"
        else
            # Standard filtered view
            "$_TAIL" -f "$file" | "$_GREP" --color=always -Ei "$regex"
        fi
    }
    _loop_render "stream" _render_log "$log_file" "$show_all"
}

ls-new() {
    : "List files by modification time; defaults to non-recursive (depth 1)"
    local dir="."
    local human_fs=false; local new_ts=false; local reverse=false
    local depth=1  # Default to 1 to prevent runaway recursion
    local OPTIND

    usage() {
        echo "Usage: ls-new [-h] [-t] [-r] [-d depth] [directory]"
        echo "  -d  Set recursion depth (default: 1; use 0 for unlimited)"
        return 1
    }

    while getopts "htrd:" opt; do
        case "$opt" in
            h) human_fs=true ;;
            t) new_ts=true ;;
            r) reverse=true ;;
            d) depth="$OPTARG" ;;
            *) usage; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))
    [[ -n "$1" ]] && dir="$1"
    [[ -d "$dir" ]] || { echo "Directory not found: $dir"; return 1; }

    local depth_arg=""
    [[ "$depth" -gt 0 ]] && depth_arg="-maxdepth $depth"

    local sort_flags='-n'
    [[ "$reverse" == true ]] && sort_flags="-nr"

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
    "$_FIND" "$dir" $depth_arg -printf "$format" | "$_SORT" $sort_flags | {
        if [[ "$human_fs" == true ]]; then
            "$_NUMFMT" --to=iec --field="$size_field" --delimiter='|' --invalid=ignore
        else
            "$_CAT"
        fi
    } | "$_CUT" -d'|' -f2- | "$_COLUMN" -t -s'|' -R "$((size_field-1))"
}

mem-top() {
    : "Aggregate memory usage (RSS) by process name"
    local count=10
    local interval=""
    local OPTIND

    usage() {
        echo "Usage: mem-top [-n count] [-i interval] [-h]"
        echo "  -n    Number of processes to display (default: 10)"
        echo "  -i    Refresh interval in seconds (enables loop mode)"
        echo "  -h    Display this help message"
        return 0
    }

    while getopts "n:i:h" opt; do
        case "$opt" in
            n) count="$OPTARG" ;;
            i) interval="$OPTARG" ;;
            h|*) usage; return 0 ;;
        esac
    done
    [[ "$count" =~ ^[0-9]+$ ]] || count=10

    _render_mem() {
        [[ -n "$interval" ]] && $_CLEAR
        local total_mem; read -r _ total_mem _ < /proc/meminfo
        echo -e "${_CLR_B_GRN}  Top $count Memory Consumers (Aggregated):${_CLR_NC} $([[ -n $interval ]] && echo "(Interval: ${interval}s)")"
        
        # Single pipe: ps -> awk (aggregate/math) -> sort -> column
        $_PS -eo user,rss,comm --no-headers | $_AWK -v tot="$total_mem" '
        { 
            # Aggregate RSS by User+Command
            key=$1"|"$3; rss[key]+=$2 
        } 
        END {
            for (i in rss) {
                split(i, k, "|");
                # Math and formatting performed within awk
                printf "%s|%.1f%%|%.2f|MB|%s\n", k[1], (rss[i]/tot)*100, rss[i]/1024, k[2]
            }
        }' | $_SORT -t'|' -rn -k3 | $_HEAD -n "$count" | $_COLUMN -t -s'|' -N "USER,%MEM,RSS,UNIT,COMMAND" -R2,3 | $_SED 's/^/    /'
    }
    # Call looping function
    _loop_render "$interval" _render_mem
}

net-audit() {
    : "Report external IP, local interfaces, gateway, DNS, and real-time transfer rates"
    local interval="" utilization_only="" tty_suffix=${TTY//\//_}

    OPTIND=1
    while getopts "hu" opt; do
        case "$opt" in
            h) echo "Usage: net-audit [-h] [-u] [interval]"; return 0 ;;
            u) utilization_only=true ;;
            *) return 10 ;;
        esac
    done
    shift $((OPTIND-1))
    interval=$1

    local ext_ip=""
    [[ -n "$_CURL" && -z "$utilization_only" ]] && ext_ip=$("$_CURL" -s --connect-timeout 3 https://ifconfig.me)

    _render_net() {
        [[ -n "$interval" ]] && $_CLEAR
        [[ -z "$utilization_only" ]] && echo -e "${_CLR_B_BLU}--- Network Audit ---${_CLR_NC} $([[ -n $interval ]] && echo "(Interval: ${interval}s)")"

        if [[ -z "$utilization_only" ]]; then
            [[ -n "$ext_ip" ]] && echo -e "${_CLR_B_GRN}External IP:${_CLR_NC} $ext_ip"
            ip-local
            echo -e "${_CLR_B_GRN}Default Gateway:${_CLR_NC}"
            $_IP route | $_GREP default | $_AWK '{print "  " $3 " via " $5}' | $_HEAD -n1
            echo -e "${_CLR_B_GRN}DNS Resolvers:${_CLR_NC}"
            [[ -n "$_RESOLVECTL" ]] && $_RESOLVECTL status | $_GREP "DNS Servers" | $_SED -E 's/^[[:space:]]+//; s/^/  /' || $_CAT /etc/resolv.conf | $_GREP nameserver | $_SED 's/^/  /'
        fi

        echo -e "${_CLR_B_GRN}Network Utilization:${_CLR_NC}"
        while read -r line; do
            local interface=$(echo "$line" | $_CUT -d: -f1 | $_XARGS)
            [[ "$interface" == "lo" ]] && continue
            
            local now=$($_DATE +%s)
            local net_file="/dev/shm/bash_stats_${tty_suffix}_net_${interface}"
            read -r _ rx_now _ _ _ _ _ _ _ tx_now _ <<< "$(echo "$line" | $_CUT -d: -f2)"
            
            local rx_speed=0 tx_speed=0
            if [[ -f "$net_file" ]]; then
                read -r last_t last_rx last_tx < "$net_file"
                local t_diff=$((now - last_t))
                [[ $t_diff -gt 0 ]] && rx_speed=$(((rx_now - last_rx) / 1024 / t_diff)) && tx_speed=$(((tx_now - last_tx) / 1024 / t_diff))
            fi
            echo "$now $rx_now $tx_now" > "$net_file"

            # Clean formatting: 12-char interface width, 7-char speed width, no extra spaces in labels
            printf "  %-12s RX: %b%s KB/s%b | TX: %b%s KB/s%b\n" \
                "${interface}:" "${_CLR_B_YLW}" "$rx_speed" "${_CLR_NC}" "${_CLR_B_YLW}" "$tx_speed" "${_CLR_NC}"
        done < <($_TAIL -n +3 /proc/net/dev)
    }
    _loop_render "$interval" _render_net
}

net-trace() {
    : "Perform a network trace to target using mtr or traceroute"
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

# Use: out2var ls -la
out2var() {
    : "Capture command standard output into the global variable out_var"
    out_var="$("$@")"
}

pkg-check() {
    : "Check versions and last update date for a list of packages"
    
    usage() {
        echo "Usage: pkg-check [-u] [package1 package2 ...]"
        echo "  -u    Display this usage information"
        return 0
    }

    local OPTIND
    while getopts "u" opt; do
        case "$opt" in
            u) usage; return 0 ;;
            *) usage; return 1 ;;
        esac
    done
    shift $((OPTIND - 1))

    [[ $# -eq 0 ]] && { echo -e "${_CLR_B_RED}Error:${_CLR_NC} No packages specified."; usage; return 1; }

    # Robust Distro Detection
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        local distro_info="${ID} ${ID_LIKE}"
    else
        return 1
    fi

    local output="Package|Installed|Latest|Last Updated\n"

    for pkg in "$@"; do
        local installed_ver="N/A" latest_ver="N/A" last_date="Unknown"

        # Debian/Ubuntu (apt-based)
        if [[ "$distro_info" =~ "debian" || "$distro_info" =~ "ubuntu" ]]; then
            if [[ -n "$_APT_CACHE" ]]; then
                while IFS='=' read -r key val; do
                    [[ "$key" == "Installed" ]] && installed_ver="$val"
                    [[ "$key" == "Candidate" ]] && latest_ver="$val"
                done < <($_APT_CACHE policy "$pkg" 2>/dev/null | $_AWK -F': ' '/Installed:|Candidate:/ {gsub(/^[ \t]+/, "", $1); print $1"="$2}')
            fi
            # Date detection: Log grep with stat fallback
            last_date=$($_GREP "status installed $pkg:" /var/log/dpkg.log* 2>/dev/null | $_SORT -r | $_HEAD -n 1 | $_CUT -d' ' -f1,2)
            if [[ -z "$last_date" && -f "/var/lib/dpkg/info/${pkg}.list" ]]; then
                last_date=$($_STAT -c '%y' "/var/lib/dpkg/info/${pkg}.list" 2>/dev/null | $_CUT -d'.' -f1)
            fi

        # Red Hat/Fedora/Enterprise Linux (rpm-based)
        elif [[ "$distro_info" =~ "rhel" || "$distro_info" =~ "fedora" || "$distro_info" =~ "centos" ]]; then
            if [[ -n "$_RPM" ]]; then
                installed_ver=$($_RPM -q --qf "%{VERSION}-%{RELEASE}" "$pkg" 2>/dev/null)
                # RPM provides installation date natively
                last_date=$($_RPM -q --last "$pkg" 2>/dev/null | $_HEAD -n 1 | $_AWK '{print $2,$3,$4,$5}')
            fi
            if [[ -n "$_DNF" ]]; then
                latest_ver=$($_DNF list updates "$pkg" 2>/dev/null | $_AWK -v p="$pkg" '$1 ~ p {print $2}')
            fi
            [[ -z "$latest_ver" || "$latest_ver" == "N/A" ]] && latest_ver=$installed_ver

        # Arch Linux (pacman-based)
        elif [[ "$distro_info" =~ "arch" ]]; then
            if [[ -n "$_PACMAN" ]]; then
                installed_ver=$($_PACMAN -Q "$pkg" 2>/dev/null | $_AWK '{print $2}')
                latest_ver=$($_PACMAN -Si "$pkg" 2>/dev/null | $_GREP "Version" | $_AWK '{print $3}')
                last_date=$($_PACMAN -Qi "$pkg" 2>/dev/null | $_GREP "Install Date" | $_CUT -d':' -f2-)
            fi
        fi

        # Color-coding for Latest column if update is available
        local latest_display="$latest_ver"
        if [[ "$installed_ver" != "$latest_ver" && "$latest_ver" != "N/A" ]]; then
            latest_display="${_CLR_B_RED}${latest_ver}${_CLR_NC}"
        fi

        output+="${pkg}|${installed_ver:-None}|${latest_display}|${last_date:-Unknown}\n"
    done

    # Final formatted render with automatic column sizing
    echo -e "$output" | $_COLUMN -t -s '|' | $_AWK -v blu="${_AWK_B_BLU}" -v nc="${_AWK_NC}" '
        NR==1 { 
            print blu $0 nc; 
            line=$0; gsub(/./, "-", line); print line; 
            next 
        } 
        { print $0 }'
}

ports-ls() {
    : "List all listening IPv4/IPv6 sockets with associated process metadata"
    echo -e "${_CLR_B_BLU}--- Listening Sockets (IPv4/IPv6) ---${_CLR_NC}"
    if [[ -n "$_SS" ]]; then
        "$_SUDO" "$_SS" -tulnp | "$_TAIL" -n +2 | "$_COLUMN" -t -N "Netid,State,Recv-Q,Send-Q,Local Address:Port,Peer Address:Port,Process"
    elif [[ -n "$_LSOF" ]]; then
        "$_SUDO" "$_LSOF" -i -P -n | "$_GREP" LISTEN
    else
        echo "Error: ss or lsof required." >&2
    fi
}

proc-top() {
    : "Display top N processes by CPU"
    local count=10
    local interval=""
    local OPTIND

    usage() {
        echo "Usage: proc-top [-n count] [-i interval] [-h]"
        echo "  -n    Number of processes to display (default: 10)"
        echo "  -i    Refresh interval in seconds (enables loop mode)"
        echo "  -h    Display this help message"
        return 0
    }

    while getopts "n:i:h" opt; do
        case "$opt" in
            n) count="$OPTARG" ;;
            i) interval="$OPTARG" ;;
            h|*) usage; return 0 ;;
        esac
    done
    [[ "$count" =~ ^[0-9]+$ ]] || count=10

    _render_proc() {
        [[ -n "$interval" ]] && $_CLEAR
        echo -e "${_CLR_B_GRN}  Top $count Processes (CPU Aggregated):${_CLR_NC} $([[ -n $interval ]] && echo "(Interval: ${interval}s)")"
        # Aggregates %CPU and RSS by process name
        # PS_FORMAT: %cpu=2, rss=3, comm=4
        $_PS -eo user,%cpu,rss,comm --no-headers | $_AWK -v count="$count" '
        {
            key=$1"|"$4;
            cpu[key]+=$2;
            rss[key]+=$3
        }
        END {
            for (i in cpu) {
                split(i, k, "|");
                # Output: User | CPU% | RSS(MB) | Command
                printf "%s|%.1f%%|%.2f|MB|%s\n", k[1], cpu[i], rss[i]/1024, k[2]
            }
        }' | $_SORT -rn -t'|' -k2 | $_HEAD -n "$count" | $_COLUMN -t -s'|' -N "USER,%CPU,RSS,UNIT,COMMAND" -R2,3 | $_SED 's/^/    /'
    }
    # Call looping function
    _loop_render "$interval" _render_proc
}

qgrep() {
    : "Recursive grep with depth control and space-safe filename handling"
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
    : "System Dashboard; Hardware, Storage, Network, and Top Resource Consumers"
    local interval="$1"

    _render_dashboard() {
        [[ -n "$interval" ]] && $_CLEAR
        echo -e "${_CLR_B_BLU}--- System Dashboard ---${_CLR_NC} $([[ -n "$interval" ]] && echo "(Interval: ${interval}s)")"
        
        # 1. OS detection: source the file to populate $PRETTY_NAME
        if [[ -f /etc/os-release ]]; then
            (. /etc/os-release; echo -e "${_CLR_B_GRN}OS:    ${_CLR_NC}$PRETTY_NAME ($($_UNAME -sr)) | ${_CLR_B_GRN}Uptime:${_CLR_NC} $($_UPTIME -p)")
        fi

        local cores;
        if [[ -f /proc/cpuinfo ]]; then
            local cpu_model; cpu_model=$($_GREP -m1 "model name" /proc/cpuinfo); cpu_model="${cpu_model#*: }"
            cores=$($_GREP -c "^processor" /proc/cpuinfo)
            echo -e "${_CLR_B_GRN}CPU:  ${_CLR_NC} $cpu_model (${_CLR_B_YLW}$cores Cores${_CLR_NC})"
        fi
    
        # 2. Load Trend & Pressure Stall Information
        if [[ -f /proc/loadavg ]] && [[ -n "$cores" ]]; then
            echo -ne "${_CLR_B_GRN}Load: ${_CLR_NC} "
            $_AWK -v n_cores="$cores" -v grn="${_AWK_B_GRN}" -v ylw="${_AWK_B_YLW}" -v red="${_AWK_B_RED}" -v nc="${_AWK_NC}" '
                function get_load_clr(val) {
                    ratio = val / n_cores;
                    if (ratio >= 1.0) return red;
                    if (ratio >= 0.7) return ylw;
                    return grn;
                }
                {
                    trend=($1>$2)? grn "↗" nc :($1<$2)? grn "↘" nc :"→";
                    printf "1m: %s%s%s, 5m: %s%s%s, 15m: %s%s%s %s\n", 
                        get_load_clr($1), $1, nc, 
                        get_load_clr($2), $2, nc, 
                        get_load_clr($3), $3, nc, trend 
                }' /proc/loadavg
        fi

        if [[ -f /proc/pressure/cpu ]]; then
            echo -ne "${_CLR_B_GRN}PSI (avg10s): ${_CLR_NC}"
            $_AWK -v grn="${_AWK_B_GRN}" -v ylw="${_AWK_B_YLW}" -v red="${_AWK_B_RED}" -v nc="${_AWK_NC}" '
                function get_clr(type, val) {
                    if (type == "cpu_some") { if (val > 5.0) return red; if (val > 0.5) return ylw; return grn; }
                    if (type == "mem_some") { if (val > 10.0) return red; if (val > 1.0) return ylw; return grn; }
                    if (type == "mem_full") { if (val > 1.0) return red; if (val > 0.1) return ylw; return grn; }
                    if (type == "io_some")  { if (val > 10.0) return red; if (val > 5.0) return ylw; return grn; }
                    if (type == "io_full")  { if (val > 5.0) return red; if (val > 1.0) return ylw; return grn; }
                    return grn;
                }
                { 
                    # Extract avg10=X.XX
                    split($2, a, "="); val=a[2]; 
                    if (FILENAME ~ /cpu/) { c_s=val }
                    else if (FILENAME ~ /memory/) { if ($1 == "some") m_s=val; else m_f=val }
                    else if (FILENAME ~ /io/) { if ($1 == "some") i_s=val; else i_f=val }
                }
                END {
                    printf "CPU: %s%s%s%% | ", get_clr("cpu_some", c_s), c_s, nc;
                    printf "MEM: %s%s%s%% (S) / %s%s%s%% (F) | ", get_clr("mem_some", m_s), m_s, nc, get_clr("mem_full", m_f), m_f, nc;
                    printf "IO: %s%s%s%% (S) / %s%s%s%% (F)\n", get_clr("io_some", i_s), i_s, nc, get_clr("io_full", i_f), i_f, nc;
                }
            ' /proc/pressure/cpu /proc/pressure/memory /proc/pressure/io 
        fi

        # 3. Memory & Swap (Standardized Color Logic)
        if [[ -f /proc/meminfo ]]; then
            $_AWK -v grn="${_AWK_B_GRN}" -v ylw="${_AWK_B_YLW}" -v red="${_AWK_B_RED}" -v nc="${_AWK_NC}" '/MemTotal|MemAvailable|SwapTotal|SwapFree/ {
                k=$1; gsub(/:/,"",k); v[k]=$2
            } END {
                m_usd=(v["MemTotal"]-v["MemAvailable"])/1024; m_tot=v["MemTotal"]/1024; m_per=(m_usd/m_tot)*100;
                clr=grn; if(m_per > 50) clr=ylw; if(m_per > 85) clr=red;
                f=int(m_per/5); e=20-f; bar=""; for(i=0;i<f;i++) bar=bar "#"; spc=""; for(i=0;i<e;i++) spc=spc "-";
                printf "  %sMem:  %s [%s%s%s%s] %3d%% (%dMB/%dMB)\n", grn, nc, clr, bar, nc, spc, m_per, m_usd, m_tot;
                
                if(v["SwapTotal"] > 0) {
                    s_usd=(v["SwapTotal"]-v["SwapFree"])/1024; s_tot=v["SwapTotal"]/1024; s_per=(s_usd/s_tot)*100;
                    clr=grn; if(s_per > 50) clr=ylw; if(s_per > 85) clr=red;
                    f=int(s_per/5); e=20-f; bar=""; for(i=0;i<f;i++) bar=bar "#"; spc=""; for(i=0;i<e;i++) spc=spc "-";
                    printf "  %sSwap: %s [%s%s%s%s] %3d%% (%dMB/%dMB)\n", grn, nc, clr, bar, nc, spc, s_per, s_usd, s_tot;
                }
            }' /proc/meminfo
        fi

        # 4. Modules
        io-audit
        echo -e "${_CLR_B_GRN}Network Status:${_CLR_NC}"
        ip-local -n
        net-audit -u 

        # 5. Fault Detection (OOM & Zombie detection)
        if [[ ! -n "$interval" ]]; then
            local faults=false
            local oom_log; oom_log=$($_DMESG -T 2>/dev/null | $_GREP -Ei "out of memory|oom-kill" | $_TAIL -n 1); [[ -n "$oom_log" ]] && faults=true
            local zombies; zombies=$($_PS -eo state,pid,comm | $_AWK '$1 == "Z" {printf "    %s [%s]\n", $2, $3}'); [[ -n "$zombies" ]] && faults=true
            [[ "$faults" == true ]] && echo -e "\n${_CLR_R_BG}${_CLR_BOLD} FAULTS DETECTED ${_CLR_NC}" 
            [[ -n "$oom_log" ]] && echo -e "\n  ${_CLR_R_BG}${_CLR_BOLD} OOM KILLER ${_CLR_NC}\n${_CLR_B_RED}$oom_log${_CLR_NC}"
            [[ -n "$zombies" ]] && echo -e "\n  ${_CLR_R_BG}${_CLR_BOLD} ZOMBIES ${_CLR_NC}\n${_CLR_B_RED}$zombies${_CLR_NC}"
        fi

        # 6. Resource Consumers
        echo -e "\n${_CLR_B_GRN}Top Resource Consumers${_CLR_NC}"
        echo -e "${_CLR_B_GRN}----------------------${_CLR_NC}"
        echo
        proc-top -n 5
        echo
        mem-top -n 5
        echo
    }
    # Call looping function
    _loop_render "$interval" _render_dashboard
}

svc-audit() {
    : "Monitor health and uptime of critical systemd services"
    local interval="$1"
    
    # Define services you consider 'critical' for your environment
    #local critical_svcs=("sshd" "docker" "nginx" "postgresql" "samba" "ufw")
    local critical_svcs=("sshd" "ufw")

    _render_svc() {
        local svc state status load_clr uptime
        [[ -n "$interval" ]] && $_CLEAR
        echo -e "${_CLR_B_BLU}--- Systemd Service Health ---${_CLR_NC} $([[ -n $interval ]] && echo "(Interval: ${interval}s)")"
        
        for svc in "${critical_svcs[@]}"; do
            # Extract state and substate in a single call
            read -r state status uptime < <($_SYSTEMCTL show "$svc" --property=ActiveState,SubState,ActiveEnterTimestamp | \
                $_SED 's/.*=//' | $_XARGS)
            
            # Logic: Active/Running = Green, anything else = Red
            if [[ "$state" == "active" ]]; then
                load_clr="$_CLR_GRN"
            else
                load_clr="$_CLR_B_RED"
            fi
            
            # Calculate uptime if available
            [[ "$uptime" == "n/a" ]] && uptime="---"
            
            printf "  %-15s : %b[%s/%s]%b  Uptime: %s\n" \
                "$svc" "$load_clr" "$state" "$status" "$_CLR_NC" "$uptime"
        done
    }   
    _loop_render "$interval" _render_svc
}

sys-audit() {
    : "Map listening ports to systemd services with process ownership"

    # Check for root/sudo for process mapping competence
    if [[ $EUID -ne 0 ]]; then
        echo -e "${_CLR_YLW}[!] Partial results: Run with sudo to resolve system-owned processes.${_CLR_NC}"
    fi

    local output="Proto|Port|Address|Service/Process|Status\n"

    while read -r proto port addr pid_info; do
        local proc_name="Unknown"
        local status="--"

        # Parse PID and Process name from ss output
        if [[ "$pid_info" =~ users:\(\(\"([^\"]+)\",pid=([0-9]+) ]]; then
            proc_name="${BASH_REMATCH[1]}"
            local pid="${BASH_REMATCH[2]}"

            # Cross-reference systemd unit
            local unit
            unit=$($_SYSTEMCTL status "$pid" 2>/dev/null | $_HEAD -n 1 | $_AWK '{print $2}')
            if [[ -n "$unit" ]]; then
                proc_name="$unit"
                status=$($_SYSTEMCTL is-active "$unit" 2>/dev/null)
            fi
        fi
        output+="${proto}|${port}|${addr}|${proc_name}|${status}\n"
    done < <($_SS -tulnpH | $_AWK '{split($5, a, ":"); print $1, a[length(a)], $5, $7}')

    echo -e "$output" | $_COLUMN -t -s '|' | $_AWK -v blu="${_AWK_B_BLU}" -v nc="${_AWK_NC}" '
        NR==1 { print blu $0 nc; line=$0; gsub(/./, "-", line); print line; next }
        { print $0 }'
}

util-ls() {
    : "Lists all defined utility functions for quick reference"
    echo -e "${_CLR_B_BLU}--- Defined Utility Functions ---${_CLR_NC}"
    # Load all function definitions into a variable once
    local funcs; funcs=$(declare -f)

    # Extract function names while excluding internal/standard ones
    while read -r func; do
        # Extract the line immediately following the function definition
        # Look for the pattern: : "description"
        # The [[:space:]]* handles variable indentation from declare -f
        if [[ "$funcs" =~ $func[[:space:]]*\(\)[[:space:]]*\{[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]]; then
            local desc="${BASH_REMATCH[1]}"
        else
            local desc="No docstring found."
        fi
        printf "${_CLR_B_GRN}%-18s${_CLR_NC}\037${_CLR_B_CYN}%s${_CLR_NC}\n" "$func" "$desc"
    done < <(declare -F | $_AWK '{print $3}' | $_GREP -vE '^(_|usage|quote|dequote|command_not_found)') | $_COLUMN -t -s $'\037'
}



# COLLISION DETECTION #
_check_collisions() {
    : Check for naming conflicts between utility functions and system binaries
    local func_list
    func_list=$(declare -F | $_AWK '{print $3}' | $_GREP -vE '^(_|usage|quote|dequote|command_not_found)')
    for func in $func_list; do
        local bin_path; bin_path=$(type -ap "$func" | $_HEAD -n 1)
        if [[ -n "$bin_path" ]]; then
            echo -e "\e[1;33m[COLLISION WARNING]${_CLR_NC} Function ${_CLR_B_GRN}$func${_CLR_NC} masks binary: ${_CLR_B_CYN}$bin_path${_CLR_NC}"
        fi
    done
}
_check_collisions
unset -f _check_collisions


# STARTUP VISUALS #
echo
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


# CLEANUP & EXIT HANDLING #
_cleanup() {
    : "Remove TTY-specific stat files from memory on exit"
    local tty_suffix=${TTY//\//_}
    # Only remove if tty_suffix is not empty to avoid globbing errors
    [[ -n "$tty_suffix" ]] && $_RM -f /dev/shm/bash_stats_"${tty_suffix}"_* 2>/dev/null
}
# Execute cleanup when the shell exits
trap _cleanup EXIT


#end bash customizations
