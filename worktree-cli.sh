#!/bin/zsh

# Main wt command - Git Worktree Manager
wt() {
    local subcommand="$1"
    shift  # Remove the subcommand from arguments
    
    case "$subcommand" in
        add)
            _wt_add "$@"
            ;;
        ls|list)
            _wt_list "$@"
            ;;
        rm|remove)
            _wt_remove "$@"
            ;;
        clean)
            _wt_clean "$@"
            ;;
        help|--help|-h|"")
            _wt_help
            ;;
        *)
            echo "Error: Unknown subcommand '$subcommand'"
            echo ""
            _wt_help
            return 1
            ;;
    esac
}

# Help function
_wt_help() {
    cat << EOF
Git Worktree Manager (wt)

Usage: wt <command> [options]

Commands:
    add <feature-name>    Create a new worktree with the given feature name
    ls, list             List all active worktrees
    rm, remove <name>    Remove a specific worktree by feature name
    clean                Remove ALL worktrees (except main)
    help                 Show this help message

Examples:
    wt add new-feature   # Create a worktree for 'new-feature' branch
    wt ls                # List all worktrees
    wt rm new-feature    # Remove the 'new-feature' worktree
    wt clean             # Remove all worktrees

Notes:
    - Worktrees are created one directory above the git root
    - Format: <project-name>-<feature-name>
    - All files (including hidden and gitignored) are copied to new worktree
    - A new terminal window will open in the worktree directory
EOF
}

# Add/Create worktree function
_wt_add() {
    local feature_name="$1"
    
    # Check if feature name is provided
    if [ -z "$feature_name" ]; then
        echo "Error: Please provide a feature name"
        echo "Usage: wt add <feature-name>"
        return 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    # Get the project folder name and git root
    local git_root=$(git rev-parse --show-toplevel)
    local project_folder_name=$(basename "$git_root")
    
    # Create the new worktree folder name
    local worktree_folder="${project_folder_name}-${feature_name}"
    local parent_dir=$(dirname "$git_root")
    local worktree_path="${parent_dir}/${worktree_folder}"
    
    # Check if the worktree folder already exists
    if [ -d "$worktree_path" ]; then
        echo "Error: Directory ${worktree_path} already exists"
        return 1
    fi
    
    # Check if branch already exists
    if git show-ref --verify --quiet "refs/heads/${feature_name}"; then
        echo "Branch '${feature_name}' already exists. Creating worktree with existing branch..."
        git worktree add "$worktree_path" "$feature_name"
    else
        echo "Creating new branch '${feature_name}' and worktree..."
        git worktree add -b "$feature_name" "$worktree_path"
    fi
    
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create worktree"
        return 1
    fi
    
    echo "Worktree created at: ${worktree_path}"
    
    # Copy all files including hidden and gitignored ones
    echo "Copying all files including hidden and gitignored files..."
    
    # Use rsync to copy everything except .git directory
    if command -v rsync &> /dev/null; then
        rsync -av --progress \
            --exclude='.git' \
            --exclude="${worktree_folder}" \
            "${git_root}/" "${worktree_path}/" 2>/dev/null
    else
        # Fallback to cp if rsync is not available
        cp -R "${git_root}/." "${worktree_path}/" 2>/dev/null
    fi
    
    echo "Files copied successfully"
    
    # Switch to the feature branch in the worktree
    cd "$worktree_path"
    git checkout "$feature_name" 2>/dev/null || git checkout -b "$feature_name" 2>/dev/null
    
    echo "Switched to branch: ${feature_name}"
    
    # Open new terminal window
    _wt_open_terminal "$worktree_path"
    
    echo ""
    echo "✅ Worktree setup complete!"
    echo "📁 Location: ${worktree_path}"
    echo "🌿 Branch: ${feature_name}"
    echo "💻 New terminal window should open in the worktree directory"
    
    # Return to original directory
    cd "$git_root"
}

# List worktrees function
_wt_list() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    echo "Current worktrees:"
    echo "─────────────────"
    
    # Get main worktree
    local main_worktree=$(git rev-parse --show-toplevel)
    
    # Parse and display worktree information
    git worktree list | while IFS= read -r line; do
        local path=$(echo "$line" | awk '{print $1}')
        local commit=$(echo "$line" | awk '{print $2}')
        local branch=$(echo "$line" | awk '{print $3}' | tr -d '[]')
        
        if [ "$path" = "$main_worktree" ]; then
            echo "📍 [MAIN] $(basename $path)"
            echo "   Path: ${path}"
            echo "   Branch: ${branch}"
            echo ""
        else
            local feature_name=$(basename "$path" | sed "s/^$(basename $main_worktree)-//")
            echo "🌿 ${feature_name}"
            echo "   Path: ${path}"
            echo "   Branch: ${branch}"
            echo ""
        fi
    done
    
    # Count worktrees
    local total=$(git worktree list | wc -l)
    local additional=$((total - 1))
    
    echo "─────────────────"
    echo "Total: ${total} worktree(s) (1 main + ${additional} additional)"
}

# Remove specific worktree function
_wt_remove() {
    local feature_name="$1"
    
    if [ -z "$feature_name" ]; then
        echo "Error: Please provide a feature name to remove"
        echo "Usage: wt rm <feature-name>"
        return 1
    fi
    
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    # Get the project folder name
    local git_root=$(git rev-parse --show-toplevel)
    local project_folder_name=$(basename "$git_root")
    
    # Construct the expected worktree path
    local parent_dir=$(dirname "$git_root")
    local worktree_folder="${project_folder_name}-${feature_name}"
    local worktree_path="${parent_dir}/${worktree_folder}"
    
    # Check if the worktree exists
    if ! git worktree list | grep -q "$worktree_path"; then
        echo "Error: Worktree for feature '${feature_name}' not found"
        echo ""
        echo "Available worktrees (use 'wt ls' for details):"
        git worktree list | while read -r line; do
            local path=$(echo "$line" | awk '{print $1}')
            if [ "$path" != "$git_root" ]; then
                echo "  - $(basename $path)"
            fi
        done
        return 1
    fi
    
    # Confirm removal
    echo "This will remove worktree: ${feature_name}"
    echo "Location: ${worktree_path}"
    echo -n "Are you sure? (y/N): "
    read -r confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Removal cancelled."
        return 0
    fi
    
    # Remove the worktree
    echo "Removing worktree..."
    if git worktree remove "$worktree_path" --force 2>/dev/null; then
        echo "✅ Worktree '${feature_name}' removed successfully"
    else
        # If git worktree remove fails, try manual cleanup
        echo "Git removal failed, attempting manual cleanup..."
        
        if [ -d "$worktree_path" ]; then
            rm -rf "$worktree_path"
            git worktree prune
            echo "✅ Worktree '${feature_name}' removed manually"
        else
            git worktree prune
            echo "✅ Worktree reference cleaned up"
        fi
    fi
}

# Clean all worktrees function
_wt_clean() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    # Get the main worktree path
    local main_worktree=$(git rev-parse --show-toplevel)
    
    # Get all worktrees
    local worktrees=$(git worktree list --porcelain | grep "^worktree" | cut -d' ' -f2)
    
    # Count and collect worktrees (excluding main)
    local count=0
    local worktree_list=""
    
    while IFS= read -r worktree; do
        if [ "$worktree" != "$main_worktree" ]; then
            ((count++))
            local feature_name=$(basename "$worktree" | sed "s/^$(basename $main_worktree)-//")
            worktree_list="${worktree_list}  - ${feature_name} (${worktree})\n"
        fi
    done <<< "$worktrees"
    
    if [ $count -eq 0 ]; then
        echo "No worktrees found to clean up."
        return 0
    fi
    
    # Show worktrees that will be removed
    echo "Found ${count} worktree(s) to remove:"
    echo -e "$worktree_list"
    
    # Ask for confirmation
    echo -n "⚠️  This will permanently delete these directories. Continue? (y/N): "
    read -r confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        return 0
    fi
    
    echo ""
    echo "Starting cleanup..."
    echo "─────────────────"
    
    # Remove each worktree
    local removed_count=0
    local failed_count=0
    
    while IFS= read -r worktree; do
        if [ "$worktree" != "$main_worktree" ]; then
            local feature_name=$(basename "$worktree" | sed "s/^$(basename $main_worktree)-//")
            echo -n "Removing '${feature_name}'... "
            
            # First, remove the git worktree reference
            if git worktree remove "$worktree" --force 2>/dev/null; then
                echo "✅"
                ((removed_count++))
            else
                # If git worktree remove fails, try manual cleanup
                echo -n "(retrying manually)... "
                
                if [ -d "$worktree" ]; then
                    rm -rf "$worktree"
                    git worktree prune
                    
                    if [ ! -d "$worktree" ]; then
                        echo "✅"
                        ((removed_count++))
                    else
                        echo "❌ Failed"
                        ((failed_count++))
                    fi
                else
                    git worktree prune
                    echo "✅ (already gone)"
                    ((removed_count++))
                fi
            fi
        fi
    done <<< "$worktrees"
    
    echo "─────────────────"
    echo "Cleanup complete!"
    echo "✅ Removed: ${removed_count} worktree(s)"
    
    if [ $failed_count -gt 0 ]; then
        echo "❌ Failed: ${failed_count} worktree(s)"
        echo "For failed worktrees, check permissions or try with sudo."
    fi
    
    # Final prune
    git worktree prune
}

# Helper function to open terminal
_wt_open_terminal() {
    local worktree_path="$1"
    
    echo "Opening new terminal in worktree directory..."
    
    # Detect and open terminal based on OS and available terminal
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if command -v wezterm &> /dev/null; then
            wezterm start --cwd "$worktree_path" &
        elif command -v alacritty &> /dev/null; then
            alacritty --working-directory "$worktree_path" &
        elif command -v kitty &> /dev/null; then
            kitty --directory "$worktree_path" &
        elif command -v iterm2 &> /dev/null; then
            osascript -e "
                tell application \"iTerm2\"
                    create window with default profile
                    tell current session of current window
                        write text \"cd ${worktree_path}\"
                    end tell
                end tell
            "
        else
            # Default Terminal.app
            osascript -e "
                tell application \"Terminal\"
                    do script \"cd ${worktree_path}\"
                    activate
                end tell
            "
        fi
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        if command -v gnome-terminal &> /dev/null; then
            gnome-terminal --working-directory="$worktree_path" &
        elif command -v konsole &> /dev/null; then
            konsole --workdir "$worktree_path" &
        elif command -v xfce4-terminal &> /dev/null; then
            xfce4-terminal --working-directory="$worktree_path" &
        elif command -v alacritty &> /dev/null; then
            alacritty --working-directory "$worktree_path" &
        elif command -v kitty &> /dev/null; then
            kitty --directory "$worktree_path" &
        elif command -v wezterm &> /dev/null; then
            wezterm start --cwd "$worktree_path" &
        elif command -v xterm &> /dev/null; then
            xterm -e "cd $worktree_path && $SHELL" &
        else
            echo "Could not detect terminal. Please open manually: ${worktree_path}"
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows
        if command -v wt &> /dev/null; then
            wt -d "$worktree_path" &
        else
            start cmd /c "cd /d ${worktree_path} && bash"
        fi
    else
        echo "Unsupported OS. Please open manually: ${worktree_path}"
    fi
}