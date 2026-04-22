#!/bin/bash
# ~/.claude/statusline-command.sh
# Claude Code status line — global, runs on every prompt redraw.
# Keep expensive operations cached or avoided entirely.
#
# DEBUG: set CLAUDE_STATUSLINE_DEBUG=1 in your environment to dump the raw
# JSON from stdin to /tmp/claude_statusline_debug.json.  Then inspect with:
#   cat /tmp/claude_statusline_debug.json | jq .context_window

# ---------------------------------------------------------------------------
# GIT SEGMENT
# One git call covers: branch name, dirty flag, and ahead/behind vs upstream.
# Uses porcelain=v2 for machine-readable output (BSD & GNU compatible).
# ---------------------------------------------------------------------------
get_git_segment() {
    local current_dir="$1"
    cd "$current_dir" 2>/dev/null || return

    git -c core.fsmonitor= rev-parse --git-dir > /dev/null 2>&1 || return

    # Single call: porcelain=v2 -b gives branch + upstream tracking in header lines
    local git_status
    git_status=$(git -c core.fsmonitor= status -b --porcelain=v2 2>/dev/null)

    # Branch name (# branch.head <name> or "(detached)")
    local branch_name
    branch_name=$(printf '%s' "$git_status" | awk '/^# branch\.head / {print $3}')
    [ -z "$branch_name" ] && branch_name="detached"

    # Dirty check: any line not starting with '#' means a tracked or untracked change
    local is_dirty=""
    if printf '%s' "$git_status" | grep -qv '^#'; then
        is_dirty=1
    fi

    # Ahead/behind: "# branch.ab +A -B"  (only present when upstream exists)
    local ahead="" behind="" ab_segment=""
    local ab_line
    ab_line=$(printf '%s' "$git_status" | awk '/^# branch\.ab / {print $3, $4}')
    if [ -n "$ab_line" ]; then
        ahead=$(printf '%s' "$ab_line" | awk '{print $1}' | tr -d '+')
        behind=$(printf '%s' "$ab_line" | awk '{print $2}' | tr -d '-')
        # Only show if non-zero
        [ "$ahead" = "0" ] && ahead=""
        [ "$behind" = "0" ] && behind=""
        [ -n "$ahead" ]  && ab_segment="${ab_segment}\033[0;33m↑${ahead}\033[0m"
        [ -n "$behind" ] && ab_segment="${ab_segment}\033[0;33m↓${behind}\033[0m"
        [ -n "$ab_segment" ] && ab_segment=" ${ab_segment}"
    fi

    if [ -n "$is_dirty" ]; then
        printf "[\033[0;31m%s\033[0;33m*\033[0m%b]" "$branch_name" "$ab_segment"
    else
        printf "[\033[0;32m%s\033[0m%b]" "$branch_name" "$ab_segment"
    fi
}

# ---------------------------------------------------------------------------
# CONTEXT PROGRESS BAR SEGMENT
# Converts used_percentage into a compact Unicode block bar (10 cells).
# Shows how much context has been USED (filled = used, empty = free).
# Color thresholds (used %):
#   < 50%  → green
#   50–85% → yellow
#   > 85%  → red
# ---------------------------------------------------------------------------
get_progress_bar() {
    local used_pct="$1"
    [ -z "$used_pct" ] && return

    local used_int
    used_int=$(printf "%.0f" "$used_pct")

    # Build a 10-cell bar based on used percentage
    local total_cells=10
    local filled=$(( used_int * total_cells / 100 ))
    [ "$filled" -gt "$total_cells" ] && filled=$total_cells

    local bar=""
    local i=0
    while [ "$i" -lt "$filled" ]; do
        bar="${bar}█"
        i=$(( i + 1 ))
    done
    while [ "$i" -lt "$total_cells" ]; do
        bar="${bar}░"
        i=$(( i + 1 ))
    done

    if [ "$used_int" -ge 85 ]; then
        printf "\033[0;31m[%s] %d%%\033[0m" "$bar" "$used_int"
    elif [ "$used_int" -ge 50 ]; then
        printf "\033[0;33m[%s] %d%%\033[0m" "$bar" "$used_int"
    else
        printf "\033[0;32m[%s] %d%%\033[0m" "$bar" "$used_int"
    fi
}

# ---------------------------------------------------------------------------
# TOKEN USAGE LABEL SEGMENT
# Displays used/total tokens as "XXk/YYYk" or "X.Xk/Y.YM" etc.
# used_tokens is always derived from the authoritative used_percentage field:
#   used_tokens = round(used_percentage * context_window_size / 100)
# used_percentage is the exact value Claude Code uses for /context — no
# approximation prefix needed.  Silent when percentage or size are unavailable,
# or when the derived token count is still zero (fresh session).
# ---------------------------------------------------------------------------
format_token_count() {
    # Format a raw token count to a human-readable string with k/M suffix.
    # Formatting rules:
    #   < 100k  → one decimal place (e.g. 85500 → "85.5k", 8500 → "8.5k")
    #   100k–999k → whole k     (e.g. 200000 → "200k")
    #   1M–9.9M  → one decimal M (e.g. 1200000 → "1.2M")
    #   >= 10M  → whole M       (e.g. 12000000 → "12M")
    local n="$1"
    if [ "$n" -ge 1000000 ]; then
        # Millions
        local whole=$(( n / 1000000 ))
        local frac=$(( (n % 1000000) / 100000 ))  # first decimal digit
        if [ "$whole" -lt 10 ]; then
            printf "%d.%dM" "$whole" "$frac"
        else
            printf "%dM" "$whole"
        fi
    elif [ "$n" -ge 100000 ]; then
        # 100k–999k: whole number of thousands
        local k=$(( (n + 500) / 1000 ))
        printf "%dk" "$k"
    else
        # Under 100k: one decimal place (e.g. 85500 → "85.5k", 8500 → "8.5k")
        local whole_k=$(( n / 1000 ))
        local frac_k=$(( (n % 1000) / 100 ))
        printf "%d.%dk" "$whole_k" "$frac_k"
    fi
}

get_token_label() {
    local total_tokens="$1"
    local used_pct="$2"

    # Require total_tokens to be a positive integer
    if [ -z "$total_tokens" ] || [ "$total_tokens" -le 0 ] 2>/dev/null; then
        return
    fi

    # used_percentage is the authoritative source — same value /context displays.
    if [ -z "$used_pct" ] || [ "$used_pct" = "null" ]; then
        return
    fi

    # Compute used_tokens from the authoritative percentage (integer arithmetic)
    local used_tokens
    used_tokens=$(( total_tokens * $(printf "%.0f" "$used_pct") / 100 ))

    # At session start percentage may round to 0 — nothing useful to render
    [ "$used_tokens" -le 0 ] && return

    local used_label
    local total_label
    used_label=$(format_token_count "$used_tokens")
    total_label=$(format_token_count "$total_tokens")

    # Dim cyan — visible but not competing with the progress bar
    printf "\033[2;36m%s/%s\033[0m" "$used_label" "$total_label"
}

# ---------------------------------------------------------------------------
# LANGUAGE / FRAMEWORK SEGMENT
# Detection order (first match wins, no deep recursion):
#   JS/TS  → package.json  → Node version + package manager (npm/yarn/pnpm/bun)
#   Go     → go.mod        → go <version>, optional framework (gin/echo/fiber/chi)
#   C#/.NET → *.csproj / *.sln / global.json → dotnet <version>, optional framework
# Falls through silently when none match.
# ---------------------------------------------------------------------------
get_lang_segment() {
    local current_dir="$1"

    # ---- JS / TS ----
    local dir="$current_dir"
    local found_pkg=""
    while [ "$dir" != "/" ] && [ "${#dir}" -ge "${#HOME}" ]; do
        if [ -f "$dir/package.json" ]; then
            found_pkg="$dir"
            break
        fi
        dir=$(dirname "$dir")
    done

    if [ -n "$found_pkg" ]; then
        local pm="npm"
        [ -f "$found_pkg/pnpm-lock.yaml" ] && pm="pnpm"
        [ -f "$found_pkg/bun.lockb" ]      && pm="bun"
        [ -f "$found_pkg/bun.lock" ]       && pm="bun"
        [ -f "$found_pkg/yarn.lock" ]      && pm="yarn"

        local node_ver=""
        if [ -f "$found_pkg/.nvmrc" ]; then
            node_ver=$(cat "$found_pkg/.nvmrc" 2>/dev/null | tr -d '[:space:]')
            node_ver="v${node_ver#v}"
        elif command -v node > /dev/null 2>&1; then
            node_ver=$(node --version 2>/dev/null)
        fi

        if [ -n "$node_ver" ]; then
            printf "\033[0;33m%s\033[2m/%s\033[0m" "$node_ver" "$pm"
        else
            printf "\033[0;33m%s\033[0m" "$pm"
        fi
        return
    fi

    # ---- Go ----
    if [ -f "$current_dir/go.mod" ]; then
        local go_ver=""
        go_ver=$(awk '/^go[[:space:]]/ {print $2; exit}' "$current_dir/go.mod" 2>/dev/null)

        local framework=""
        # Detect common frameworks from require lines in go.mod
        if grep -q 'github\.com/gin-gonic/gin' "$current_dir/go.mod" 2>/dev/null; then
            framework="gin"
        elif grep -q 'github\.com/labstack/echo' "$current_dir/go.mod" 2>/dev/null; then
            framework="echo"
        elif grep -q 'github\.com/gofiber/fiber' "$current_dir/go.mod" 2>/dev/null; then
            framework="fiber"
        elif grep -q 'github\.com/go-chi/chi' "$current_dir/go.mod" 2>/dev/null; then
            framework="chi"
        fi

        if [ -n "$go_ver" ] && [ -n "$framework" ]; then
            printf "\033[0;36mgo %s\033[2m/%s\033[0m" "$go_ver" "$framework"
        elif [ -n "$go_ver" ]; then
            printf "\033[0;36mgo %s\033[0m" "$go_ver"
        else
            printf "\033[0;36mgo\033[0m"
        fi
        return
    fi

    # ---- C# / .NET ----
    # Check for .csproj, .sln, or global.json in current_dir only (no deep recursion)
    local dotnet_marker=""
    local csproj_file=""
    csproj_file=$(ls "$current_dir"/*.csproj 2>/dev/null | head -1)
    [ -n "$csproj_file" ] && dotnet_marker="$csproj_file"
    [ -z "$dotnet_marker" ] && ls "$current_dir"/*.sln > /dev/null 2>&1 && dotnet_marker="sln"
    [ -z "$dotnet_marker" ] && [ -f "$current_dir/global.json" ] && dotnet_marker="$current_dir/global.json"

    if [ -n "$dotnet_marker" ]; then
        # Try to get dotnet version from global.json first, then running binary
        local dotnet_ver=""
        if [ -f "$current_dir/global.json" ]; then
            dotnet_ver=$(jq -r '.sdk.version // empty' "$current_dir/global.json" 2>/dev/null)
        fi
        if [ -z "$dotnet_ver" ] && command -v dotnet > /dev/null 2>&1; then
            dotnet_ver=$(dotnet --version 2>/dev/null)
        fi

        # Detect framework from .csproj Sdk attribute or PackageReference
        local framework=""
        if [ -n "$csproj_file" ] && [ -f "$csproj_file" ]; then
            if grep -qi 'Sdk="Microsoft\.NET\.Sdk\.Web"' "$csproj_file" 2>/dev/null; then
                framework="ASP.NET Core"
            elif grep -qi 'Sdk="Microsoft\.NET\.Sdk\.BlazorWebAssembly"\|Blazor' "$csproj_file" 2>/dev/null; then
                framework="Blazor"
            elif grep -qi 'Microsoft\.Maui' "$csproj_file" 2>/dev/null; then
                framework="MAUI"
            fi
        fi

        if [ -n "$dotnet_ver" ] && [ -n "$framework" ]; then
            printf "\033[0;35mdotnet %s\033[2m/%s\033[0m" "$dotnet_ver" "$framework"
        elif [ -n "$dotnet_ver" ]; then
            printf "\033[0;35mdotnet %s\033[0m" "$dotnet_ver"
        else
            printf "\033[0;35mdotnet\033[0m"
        fi
        return
    fi
}

# ---------------------------------------------------------------------------
# AWS PROFILE SEGMENT
# Zero-cost: reads $AWS_PROFILE / $AWS_VAULT env vars already in environment.
# $AWS_VAULT takes precedence (it implies an active session via aws-vault).
# ---------------------------------------------------------------------------
get_aws_segment() {
    local profile=""
    if [ -n "$AWS_VAULT" ]; then
        profile="$AWS_VAULT"
    elif [ -n "$AWS_PROFILE" ]; then
        profile="$AWS_PROFILE"
    fi
    [ -z "$profile" ] && return
    printf "\033[0;33m☁ %s\033[0m" "$profile"
}

# ---------------------------------------------------------------------------
# EFFORT LEVEL SEGMENT
# Source priority:
#   1. JSON payload — probes .effort, .effort_level, .model.effort,
#      .model.effort_level, .config.effort (first non-null wins).
#   2. Fallback: ~/.claude/settings.json → .effortLevel
#   3. Silent when neither source provides a value.
# Color: \033[2;35m  dim magenta — visually groups with the bright-magenta
# model bracket without competing for attention.
# ---------------------------------------------------------------------------
get_effort_segment() {
    local json_input="$1"
    local effort=""

    # Probe JSON candidates in priority order
    effort=$(printf '%s' "$json_input" | jq -r '
        .effort //
        .effort_level //
        .model.effort //
        .model.effort_level //
        .config.effort //
        empty' 2>/dev/null)

    # Fallback to settings.json when JSON payload has no effort field
    if [ -z "$effort" ]; then
        local settings="$HOME/.claude/settings.json"
        if [ -f "$settings" ]; then
            effort=$(jq -r '.effortLevel // empty' "$settings" 2>/dev/null)
        fi
    fi

    [ -z "$effort" ] && return
    printf "\033[2;35m[%s]\033[0m" "$effort"
}

# ---------------------------------------------------------------------------
# OPTIONAL: kubectl context  — DISABLED by default (slow ~150ms on macOS).
# Uncomment the body below and comment-out the early return to enable.
# Results are cached for 10s to /tmp/claude_statusline_kube_ctx.
# ---------------------------------------------------------------------------
get_kube_segment() {
    return  # remove this line to enable kubectl context display

    local cache_file="/tmp/claude_statusline_kube_ctx"
    local now
    now=$(date +%s)
    local cache_age=0
    if [ -f "$cache_file" ]; then
        # BSD stat (macOS): -f %m gives mtime as epoch seconds
        local mtime
        mtime=$(stat -f %m "$cache_file" 2>/dev/null || echo 0)
        cache_age=$(( now - mtime ))
    fi
    local ctx=""
    if [ "$cache_age" -lt 10 ] && [ -f "$cache_file" ]; then
        ctx=$(cat "$cache_file" 2>/dev/null)
    else
        ctx=$(kubectl config current-context 2>/dev/null)
        printf '%s' "$ctx" > "$cache_file" 2>/dev/null
    fi
    [ -z "$ctx" ] && return
    printf " \033[0;36mK8s:%s\033[0m" "$ctx"
}

# ---------------------------------------------------------------------------
# PARSE STDIN JSON (single read, reused for all fields)
# ---------------------------------------------------------------------------
input=$(cat)

if [ "${CLAUDE_STATUSLINE_DEBUG:-0}" = "1" ]; then
    printf '%s' "$input" > /tmp/claude_statusline_debug.json 2>/dev/null
fi

current_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // ""')
model_name=$(printf '%s' "$input"  | jq -r '.model.display_name // ""')
output_style=$(printf '%s' "$input" | jq -r '.output_style.name // ""')

# Context window fields
# used_percentage / remaining_percentage: pre-calculated by Claude Code (0-100 or null)
used_pct=$(printf '%s' "$input"      | jq -r '.context_window.used_percentage // empty')
remaining_pct=$(printf '%s' "$input" | jq -r '.context_window.remaining_percentage // empty')
# Derive used_pct from remaining_pct when only the latter is present
if [ -z "$used_pct" ] && [ -n "$remaining_pct" ]; then
    used_pct=$(awk "BEGIN {printf \"%.2f\", 100 - $remaining_pct}")
fi

# context_window_size: maximum tokens for this model (e.g. 200000 for Claude 3/3.5)
ctx_size=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // empty')

# Fallback to pwd if current_dir not provided
[ -z "$current_dir" ] && current_dir=$(pwd)

# ---------------------------------------------------------------------------
# ASSEMBLE SEGMENTS WITH GRAY DIVIDERS
# Strategy: collect each segment's text into an array, then join with dividers.
# Each getter emits ONLY its content — no leading/trailing spaces.
# The assembly loop injects " \033[0;90m|\033[0m " between non-empty segments.
# This guarantees no orphan dividers when optional segments are suppressed.
# ---------------------------------------------------------------------------

DIV=" \033[0;90m|\033[0m "

# 1. user@dir  (bold cyan user, bold blue dir, zsh-style ~ for $HOME)
# Printed as the LEADING token — no divider before or after it.
# All subsequent segments are joined with " | " and appended with a plain space.
user=$(whoami)
display_dir="${current_dir/#$HOME/~}"
user_dir=$(printf "\033[1;36m%s@\033[1;34m%s\033[0m" "$user" "$display_dir")

segments=()

# 2. Git branch + dirty flag + ahead/behind arrows
git_segment=$(get_git_segment "$current_dir")
[ -n "$git_segment" ] && segments+=("$git_segment")

# 3. Model name  [magenta bold]
if [ -n "$model_name" ]; then
    segments+=("$(printf "\033[1;35m[%s]\033[0m" "$model_name")")
fi

# 3b. Effort level  [dim magenta] — immediately after model, before progress bar
effort_segment=$(get_effort_segment "$input")
[ -n "$effort_segment" ] && segments+=("$effort_segment")

# 4. Context progress bar  (green < 50% | yellow 50-85% | red > 85%)
progress_bar=$(get_progress_bar "$used_pct")
[ -n "$progress_bar" ] && segments+=("$progress_bar")

# 5. Token count label  (dim cyan; derived from authoritative used_percentage)
token_label=$(get_token_label "$ctx_size" "$used_pct")
[ -n "$token_label" ] && segments+=("$token_label")

# 6. Language / framework segment  (JS/TS, Go, or C#/.NET — silent fallthrough)
lang_segment=$(get_lang_segment "$current_dir")
[ -n "$lang_segment" ] && segments+=("$lang_segment")

# 7. AWS profile (only when $AWS_PROFILE or $AWS_VAULT is set)
aws_segment=$(get_aws_segment)
[ -n "$aws_segment" ] && segments+=("$aws_segment")

# 8. Output style  (only when non-default / non-empty)
if [ -n "$output_style" ] && [ "$output_style" != "default" ] && [ "$output_style" != "Default" ]; then
    segments+=("$(printf "\033[2m[%s]\033[0m" "$output_style")")
fi

# kubectl context  (disabled; see get_kube_segment above to enable)
# kube_segment=$(get_kube_segment)
# [ -n "$kube_segment" ] && segments+=("$kube_segment")

# Print user@dir as the leading token, then join remaining segments with " | ".
# A plain space (no divider) separates user@dir from whatever comes first.
printf "%s" "$user_dir"
if [ "${#segments[@]}" -gt 0 ]; then
    # Build joined string for all subsequent segments
    joined=""
    first=1
    for seg in "${segments[@]}"; do
        if [ "$first" = "1" ]; then
            joined="$seg"
            first=0
        else
            joined="${joined}$(printf "%b" "$DIV")${seg}"
        fi
    done
    printf " %b" "$joined"
fi

printf "\n"