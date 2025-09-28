#!/bin/bash

# Get Claude Code session token usage
get_token_usage() {
    local transcript_path="$1"
    if [ -f "$transcript_path" ]; then
        # Estimate tokens from transcript file size and content
        local file_size=$(stat -f%z "$transcript_path" 2>/dev/null || echo "0")
        local estimated_tokens=$((file_size / 4))  # Rough estimate: 4 chars per token
        echo "$estimated_tokens"
    else
        echo "0"
    fi
}

# Calculate context left percentage
get_context_left() {
    local transcript_path="$1"
    local model_id="$2"

    # Context window sizes by model
    case "$model_id" in
        *"claude-3-5-sonnet"*) context_window=200000 ;;
        *"claude-3-opus"*) context_window=200000 ;;
        *"claude-3-haiku"*) context_window=200000 ;;
        *"opusplan"*) context_window=400000 ;;
        *) context_window=200000 ;;
    esac

    local used_tokens=$(get_token_usage "$transcript_path")
    local context_left_percent=$(((context_window - used_tokens) * 100 / context_window))

    # Ensure it doesn't go below 0
    if [ $context_left_percent -lt 0 ]; then
        context_left_percent=0
    fi

    echo "$context_left_percent"
}

# Get branch name only
get_branch_id() {
    local current_dir="$1"
    cd "$current_dir" 2>/dev/null || return

    if git rev-parse --git-dir > /dev/null 2>&1; then
        local branch_name=$(git branch --show-current 2>/dev/null)

        if [ -n "$branch_name" ]; then
            echo "$branch_name"
        else
            echo "detached"
        fi
    else
        echo "no-git"
    fi
}

# Get initial prompt summarization (first user message from JSONL transcript)
get_prompt_summary() {
    local transcript_path="$1"
    if [ -f "$transcript_path" ]; then
        # Extract first user message from JSONL transcript
        local first_prompt=$(grep -m1 '"role":"user"' "$transcript_path" 2>/dev/null | jq -r '.message.content // .content // ""' 2>/dev/null | cut -c1-50)
        if [ -n "$first_prompt" ] && [ "$first_prompt" != "null" ] && [ "$first_prompt" != "" ]; then
            echo "${first_prompt}..."
        else
            echo "new-session"
        fi
    else
        echo "no-transcript"
    fi
}

# Parse input JSON
input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "unknown"')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')
model_id=$(echo "$input" | jq -r '.model.id // ""')
model_name=$(echo "$input" | jq -r '.model.display_name // ""')

# Fallback to pwd if current_dir not available
if [ -z "$current_dir" ]; then
    current_dir=$(pwd)
fi

# Gather all Claude Code specific information
token_usage=$(get_token_usage "$transcript_path")
context_left=$(get_context_left "$transcript_path" "$model_id")
branch_id=$(get_branch_id "$current_dir")
prompt_summary=$(get_prompt_summary "$transcript_path")

# Format token usage with K/M suffixes
if [ $token_usage -gt 1000000 ]; then
    token_display="$((token_usage / 1000000))M"
elif [ $token_usage -gt 1000 ]; then
    token_display="$((token_usage / 1000))K"
else
    token_display="$token_usage"
fi

# Build Claude Code focused status line
printf "\033[1;35m[%s]\033[0m \033[1;33m%s\033[0m | \033[0;36mTokens:\033[1;34m%s\033[0m \033[0;36mContext:\033[1;32m%s%%\033[0m \033[0;36mBranch:\033[1;33m%s\033[0m\n" \
    "$model_name" \
    "$prompt_summary" \
    "$token_display" \
    "$context_left" \
    "$branch_id"