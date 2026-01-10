# INTERACTIVE CHECK & INITIALIZATION #
# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Ensure TTY is set and clean stale stats
[[ -z "$TTY" ]] && TTY=$(tty)
tty_suffix=${TTY//\//_}


# SET SECURE BIN PATHS #
# Define the common binary search paths
BIN_SEARCH_PATHS=("/usr/bin" "/bin" "/usr/local/bin")

# Define the commands you want to secure
# Combined List for initial path validation
CMDS=(basename cat clear column cut date df dmesg du find grep gunzip head ip join kill ls less more notify-send numfmt ps readlink rm sed sleep sort ssh stat sudo tar tail tr unzip uname uptime watch xargs)
OPTIONAL_CMDS=(7z awk bunzip2 curl dig lsof md5sum mtr netstat nmtui pgrep resolvectl sha256sum ss systemctl tmux traceroute unrar uncompress)

# Single pass to map binaries to variables and aliases
for cmd in "${CMDS[@]}" "${OPTIONAL_CMDS[@]}"; do
    found=false
    for path in "${BIN_SEARCH_PATHS[@]}"; do
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
                echo "Error: Critical binary '$cmd' not found" >&2
            fi
        done
    fi
done


# CLEANUP OLD SESSION STATS #
$_RM -f /dev/shm/bash_*_stats"${tty_suffix}" 2>/dev/null


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
# ANSI Color Codes (High Intensity/Bold)
export _CLR_B_GRN='\e[1;32m'  # Nominal / Success
export _CLR_GRN='\e[32m'      # Nominal / Success
export _CLR_B_YLW='\e[1;33m'  # Warning / Transition
export _CLR_YLW='\e[33m'      # Warning / Transition
export _CLR_B_RED='\e[1;31m'  # Critical / Error
export _CLR_RED='\e[31m'      # Critical / Error
export _CLR_B_BLU='\e[1;34m'  # Headers / Info
export _CLR_B_CYN='\e[36m'    # Secondary Info
export _CLR_BOLD='\e[1m'      # High Emphasis
export _CLR_R_BG='\e[41;37m'  # Alert (White on Red)
export _CLR_NC='\e[0m'        # No Color (Reset)

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
    local G='\[\e[01;32m\]' B='\[\e[01;34m\]' C='\[\e[36m\]'
    local R='\[\e[31m\]' W='\[\e[00m\]' BOLD='\[\e[01m\]'

    # Check return/exit status
    if (( EXIT == 0 )); then
        local STATUS="${C}[\j| \! ]${G}"
    else
        local STATUS="${R}[\j|\!|$EXIT]"
    fi

    # Build prompt
    PS1="${debian_chroot:+($debian_chroot)}${G}\u@\h${B} \w ${BOLD}${STATUS} \$${W} "
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
    if [[ "$interval" =~ ^[0-9]+$ ]]; then
        trap 'break' SIGINT
        while true; do "$render_func" "$@"; $_SLEEP "$interval"; done
        trap - SIGINT
    else
        "$render_func" "$@"
    fi
}

bin-audit() {
    : "Audit environment for required and optional binaries and mapping status"
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
    local func_list; func_list=$(declare -F | $_AWK '{print $3}' | $_GREP -vE '^(_|usage|quote|dequote|command_not_found)')
    local found_collision=false

    for func in $func_list; do
        local bin_path; bin_path=$(type -ap "$func" | $_HEAD -n 1)
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
    "$_DU" -hd 1 "$dir" 2>/dev/null | "$_SORT" -hr | "$_SED" "$((count + 1))q" | "$_COLUMN" -t
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
    local iops_file="/dev/shm/bash_iops_stats${tty_suffix}"

    _render_io() {
        local now; now=$($_DATE +%s)
        [[ -n "$interval" ]] && $_CLEAR
        echo -e "${_CLR_B_GRN}Storage Monitoring${_CLR_NC} $([[ -n "$interval" ]] && echo "(Interval: ${interval}s)")"

        local stats_snapshot; stats_snapshot=$($_CAT /proc/diskstats)
        
        # Capture columns directly: dev_node=$1, fs_size=$2, fs_perc=$5, fs_mnt=$6
        while read -r dev_node fs_size _ _ fs_perc fs_mnt; do
            # Filter for relevant storage types
            [[ "$dev_node" =~ ^(/dev/|zroot|pool) ]] || continue

            local perc_val="${fs_perc%%%}"
            local block_dev="${dev_node##*/}"

            # Standard block device resolution
            if [[ -d "/sys/class/block/$block_dev/slaves" ]]; then
                local slave; slave=$($_LS "/sys/class/block/$block_dev/slaves" | $_HEAD -n1)
                [[ -n "$slave" ]] && block_dev="$slave"
            fi

            local dev_stats; dev_stats=$($_GREP -w "$block_dev" <<< "$stats_snapshot")
            # Mapping /proc/diskstats: 4=riops, 6=rsect, 8=wiops, 10=wsect
            # We use '_' to skip irrelevant indices
            read -r _ _ _ riops_now _ rsect_now _ wiops_now _ wsect_now _ <<< "$dev_stats"

            local s_size; s_size=$($_CAT "/sys/class/block/$block_dev/queue/hw_sector_size" 2>/dev/null || echo 512)

            local r_speed="0.00" w_speed="0.00" r_iops="0" w_iops="0"
            if [[ -f "$iops_file" ]]; then
                local last_data; last_data=$($_GREP "^$block_dev " "$iops_file")
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

            local f=$((perc_val / 5)) e=$((20 - f))
            local bar; printf -v bar "%${f}s" ""; bar=${bar// /#}
            local spc; printf -v spc "%${e}s" ""; spc=${spc// /-}

            local threshold=90; [[ "$fs_mnt" == "/" || "$fs_mnt" == "/boot"* ]] && threshold=80
            local alert=" "; [[ $perc_val -ge $threshold ]] && alert="${_CLR_R_BG}!${_CLR_NC}"

            printf "  %b %-15s [%s] [%b%s%b%s] %3d%% | R:%5s KB/s (%s iops) | W:%5s KB/s (%s iops)\n" \
                "$alert" "$fs_mnt" "$fs_size" "$BAR_COLOR" "$bar" "$_CLR_NC" "$spc" "$perc_val" "$r_speed" "$r_iops" "$w_speed" "$w_iops"

        done < <($_DF -h)
    }
    _loop_render "$interval" _render_io
}

ip-local() {
    : "Mapping of network interfaces to IP, MAC, and Status"
    echo -e "${_CLR_B_GRN}Interface IP/MAC Mapping:${_CLR_NC}"

    local link_info=$($_IP -brief link show)
    
    $_IP -brief addr show | $_AWK -v links="$link_info" '
    BEGIN {
        n = split(links, a, "\n")
        for (i=1; i<=n; i++) {
            split(a[i], b)
            meta[b[1]] = b[2] "  " b[3]
        }
    }
    {
        printf "%-10s %-20s %s\n", $1, $3, meta[$1]
    }' | $_COLUMN -t | $_SED 's/^/  /'
}

log-watch() {
    : "Stream log files with high-visibility color highlighting for errors/critical events"
    local log_file="${1:-/var/log/syslog}"
    [[ -f "$log_file" ]] || { echo "Error: Log file $log_file not found."; return 1; }

    echo -e "${_CLR_B_BLU}--- Watching $log_file [Ctrl+C to exit] ---${_CLR_NC}"

    # Highlight keywords: ERROR, FATAL, FAIL, CRITICAL, DENIED
    "$_TAIL" -f "$log_file" | "$_GREP" --color=always -Ei 'error|fatal|fail|critical|denied|warn|panic'
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
    local interval="$1"
    local tty_suffix=${TTY//\//_}
    local net_file="/dev/shm/bash_net_stats${tty_suffix}"

    usage() {
        echo "Usage: net-audit [-h] [interval_seconds]"
        echo "  -h                Display this help message"
        echo "  interval_seconds  Optional. If set, runs in a real-time loop."
        return 0
    }

    case "$1" in
        "-h") usage; return 0 ;;
        ''|[0-9]*) interval="$1" ;;
        *) usage; return 10 ;;
    esac

    local ext_ip=""
    if [[ -n "$_CURL" ]]; then
        ext_ip=$("$_CURL" -s --connect-timeout 3 https://ifconfig.me)
    fi

    _render_net() {
        [[ -n "$interval" ]] && $_CLEAR
        echo -e "${_CLR_B_BLU}--- Network Audit ---${_CLR_NC} $([[ -n $interval ]] && echo "(Interval: ${interval}s)")"
        
        [[ -n "$ext_ip" ]] && echo -e "${_CLR_B_GRN}External IP:${_CLR_NC} $ext_ip"

        ip-local

        echo -ne "${_CLR_B_GRN}Default Gateway:${_CLR_NC} "
        if [[ -f /proc/net/route ]]; then
            local gw_hex=$("$_AWK" '$2 == "00000000" {print $3}' /proc/net/route | $_HEAD -n1)
            if [[ -n "$gw_hex" ]]; then
                printf "%d.%d.%d.%d\n" 0x${gw_hex:6:2} 0x${gw_hex:4:2} 0x${gw_hex:2:2} 0x${gw_hex:0:2}
            else
                echo "None"
            fi
        else
            $_IP route | "$_GREP" default | "$_AWK" '{print $3}'
        fi

        echo -e "${_CLR_B_GRN}DNS Resolvers:${_CLR_NC}"
        if [[ -n "$_RESOLVECTL" ]]; then
            $_RESOLVECTL status | $_GREP "DNS Servers" | $_SED -E 's/^[[:space:]]+//; s/^/  /'
        else
            $_CAT /etc/resolv.conf | $_GREP nameserver | $_SED 's/^/  /'
        fi
        
        local interface; read -r _ _ _ _ interface _ < <($_IP route | $_GREP default | $_HEAD -n1)
        if [[ -n "$interface" && -f /proc/net/dev ]]; then
            local now=$($_DATE +%s)
            read -r _ rx_now _ _ _ _ _ _ _ tx_now _ <<< "$($_GREP "$interface" /proc/net/dev)"
            local rx_speed=0; local tx_speed=0

            if [[ -f "$net_file" ]]; then
                read -r last_t last_rx last_tx < "$net_file"
                local t_diff=$((now - last_t))
                [[ $t_diff -gt 0 ]] && rx_speed=$(((rx_now - last_rx) / 1024 / t_diff)) && tx_speed=$(((tx_now - last_tx) / 1024 / t_diff))
            fi
            echo "$now $rx_now $tx_now" > "$net_file"
            printf "${_CLR_B_GRN}Net Rates ($interface):${_CLR_NC} RX: ${_CLR_B_YLW}%s KB/s${_CLR_NC} | TX: ${_CLR_B_YLW}%s KB/s${_CLR_NC}\n" "$rx_speed" "$tx_speed"
        fi
    }
    # Call looping function
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
        local interface; interface=$($_IP route | $_GREP default | $_AWK '{print $5}' | $_HEAD -n1)
        [[ -n "$interface" ]] && net-audit | $_GREP "Net Rates"

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
    [[ -n "$tty_suffix" ]] && $_RM -f /dev/shm/bash_*_stats"${tty_suffix}"
}
# Execute cleanup when the shell exits
trap _cleanup EXIT


#end bash customizations