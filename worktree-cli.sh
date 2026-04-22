#!/bin/zsh

# Main wt command - Git Worktree Manager
wt() {
    local subcommand="$1"
    shift  # Remove the subcommand from arguments
    
    case "$subcommand" in
        add)
            # Run in subshell with job control disabled to suppress notifications
            ( set +m 2>/dev/null; _wt_add "$@" )
            ;;
        ls|list)
            _wt_list "$@"
            ;;
        rm|remove)
            _wt_remove "$@"
            ;;
        clean)
            # Run in subshell with job control disabled to suppress notifications
            ( set +m 2>/dev/null; _wt_clean "$@" )
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
    clean                Remove ALL worktrees AND branches (except main)
    help                 Show this help message

Examples:
    wt add new-feature   # Create a worktree for 'new-feature' branch
    wt ls                # List all worktrees
    wt rm new-feature    # Remove the 'new-feature' worktree
    wt clean             # Remove all worktrees and branches

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
    
    # Sanitize feature name for folder creation (replace / with -)
    local sanitized_name="${feature_name//\//-}"
    
    # Create the new worktree folder name
    local worktree_folder="${project_folder_name}-${sanitized_name}"
    local parent_dir=$(dirname "$git_root")
    local worktree_path="${parent_dir}/${worktree_folder}"
    
    # Check if the worktree folder already exists
    if [ -d "$worktree_path" ]; then
        echo "Error: Directory ${worktree_path} already exists"
        return 1
    fi
    
    # Step 1: Create git worktree with progress
    printf "Git worktree: "
    
    # Run git command in subshell to avoid job notifications
    (
        if git show-ref --verify --quiet "refs/heads/${feature_name}"; then
            exec git worktree add "$worktree_path" "$feature_name" > /dev/null 2>&1
        else
            exec git worktree add -b "$feature_name" "$worktree_path" > /dev/null 2>&1
        fi
    ) &
    
    local git_pid=$!
    
    # Show progress for git worktree
    local dots=""
    while kill -0 $git_pid 2>/dev/null; do
        printf "\rGit worktree: [%-20s]" "$dots"
        dots="${dots}##"
        if [ ${#dots} -gt 20 ]; then
            dots="##"
        fi
        sleep 0.1
    done 2>/dev/null
    
    wait $git_pid 2>/dev/null
    local git_result=$?
    
    if [ $git_result -ne 0 ]; then
        printf "\rGit worktree: [FAILED              ]\n"
        echo "Error: Failed to create worktree"
        return 1
    fi
    
    printf "\rGit worktree: [####################] 100%%\n"
    
    # Step 2: Copy hidden/ignored files with progress
    printf "Copying project files: "
    
    # Use rsync if available for better performance
    if command -v rsync &> /dev/null; then
        # Run rsync in subshell to avoid job notifications
        (
            exec rsync -a \
                --exclude='.git' \
                --exclude="${worktree_folder}" \
                "${git_root}/" "${worktree_path}/" 2>/dev/null
        ) &
        
        local rsync_pid=$!
        
        # Simple progress animation while rsync runs
        local progress=0
        
        while kill -0 $rsync_pid 2>/dev/null; do
            # Create progress bar
            local filled=$((progress / 5))
            local bar=$(printf "%${filled}s" | tr ' ' '#')
            local empty=$((20 - filled))
            local spaces=$(printf "%${empty}s")
            
            printf "\rCopying project files: [%s%s] %d%%" "$bar" "$spaces" "$progress"
            
            # Update progress
            if [ $progress -lt 95 ]; then
                progress=$((progress + 3))
            fi
            sleep 0.05
        done 2>/dev/null
        
        wait $rsync_pid 2>/dev/null
        printf "\rCopying project files: [####################] 100%%\n"
    else
        # Fallback to cp with simple progress
        cp -R "${git_root}/." "${worktree_path}/" 2>/dev/null
        printf "[####################] 100%%\n"
    fi
    
    # Switch to the feature branch in the worktree
    cd "$worktree_path"
    git checkout "$feature_name" > /dev/null 2>&1 || git checkout -b "$feature_name" > /dev/null 2>&1
    
    # Open new terminal window
    _wt_open_terminal "$worktree_path" > /dev/null 2>&1
    
    # Show summary
    echo ""
    echo "Summary:"
    echo "--------"
    echo "✓ Git worktree created with branch: ${feature_name}"
    echo "✓ All project files copied (including .env, node_modules, etc.)"
    echo ""
    printf "%-20s %s\n" "Worktree name:" "${worktree_folder}"
    printf "%-20s %s\n" "Branch:" "${feature_name}"
    printf "%-20s %s\n" "Location:" "${worktree_path}"
    echo ""
    
    # Return to original directory
    cd "$git_root"
}

# List worktrees function
_wt_list() {
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "Error: Not in a git repository"
        return 1
    fi
    
    # Get main worktree
    local main_worktree=$(git rev-parse --show-toplevel)
    
    printf "\n%-30s %-30s %s\n" "NAME" "BRANCH" "PATH"
    
    # Parse and display worktree information
    git worktree list | while IFS= read -r line; do
        # Extract path (first field)
        local wt_path=${line%% *}
        
        # Extract branch name (text within brackets)
        local branch_part=${line#*\[}
        local branch=${branch_part%\]*}
        
        # Get the base name of the path
        local name=${wt_path##*/}
        
        # Mark main worktree
        if [ "$wt_path" = "$main_worktree" ]; then
            printf "%-30s %-30s %s\n" "${name} [main]" "$branch" "$wt_path"
        else
            printf "%-30s %-30s %s\n" "$name" "$branch" "$wt_path"
        fi
    done
    
    echo ""
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
    
    # Sanitize feature name for folder lookup (replace / with -)
    local sanitized_name="${feature_name//\//-}"
    
    # Construct the expected worktree path
    local parent_dir=$(dirname "$git_root")
    local worktree_folder="${project_folder_name}-${sanitized_name}"
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
    
    # Get all worktrees with branch information
    local worktree_info=$(git worktree list --porcelain)
    
    # Count and collect worktrees (excluding main) with their branches
    local count=0
    local worktree_list=""
    local branch_list=""
    local branches_to_delete=""
    
    # Parse worktree info to extract paths and branches
    local current_worktree=""
    local current_branch=""
    
    while IFS= read -r line; do
        if [[ "$line" == worktree* ]]; then
            current_worktree="${line#worktree }"
        elif [[ "$line" == branch* ]]; then
            current_branch="${line#branch refs/heads/}"
            
            # Process the worktree-branch pair if we have both and it's not main
            if [ -n "$current_worktree" ] && [ -n "$current_branch" ] && [ "$current_worktree" != "$main_worktree" ]; then
                ((count++))
                local feature_name=$(basename "$current_worktree" | sed "s/^$(basename $main_worktree)-//")
                worktree_list="${worktree_list}  - ${feature_name} (${current_worktree})\n"
                branch_list="${branch_list}  - ${current_branch}\n"
                branches_to_delete="${branches_to_delete}${current_branch}\n"
            fi
            
            # Reset for next iteration
            current_worktree=""
            current_branch=""
        elif [ -z "$line" ]; then
            # Empty line resets state
            current_worktree=""
            current_branch=""
        fi
    done <<< "$worktree_info"
    
    if [ $count -eq 0 ]; then
        echo "No worktrees found to clean up."
        return 0
    fi
    
    # Show worktrees and branches that will be removed
    echo "Found ${count} worktree(s) to remove:"
    echo -e "$worktree_list"
    echo "Associated branches that will be deleted:"
    echo -e "$branch_list"
    
    # Ask for confirmation
    echo -n "This will permanently delete these directories AND branches. Continue? (y/N): "
    read -r confirmation
    
    if [[ ! "$confirmation" =~ ^[Yy]$ ]]; then
        echo "Cleanup cancelled."
        return 0
    fi
    
    echo ""
    printf "Removing worktrees: "
    
    # Parse worktree info again to get worktree paths for removal
    local worktrees_to_remove=""
    local current_worktree=""
    local current_branch=""
    
    while IFS= read -r line; do
        if [[ "$line" == worktree* ]]; then
            current_worktree="${line#worktree }"
        elif [[ "$line" == branch* ]]; then
            current_branch="${line#branch refs/heads/}"
            
            # Add worktree to removal list if it's not main
            if [ -n "$current_worktree" ] && [ -n "$current_branch" ] && [ "$current_worktree" != "$main_worktree" ]; then
                worktrees_to_remove="${worktrees_to_remove}${current_worktree}\n"
            fi
            
            # Reset for next iteration
            current_worktree=""
            current_branch=""
        fi
    done <<< "$worktree_info"
    
    # Remove each worktree with progress bar
    local removed_count=0
    local failed_count=0
    local current=0
    
    while IFS= read -r worktree; do
        if [ -n "$worktree" ]; then
            ((current++))
            
            # Calculate and show progress
            local progress=$((current * 100 / count))
            local bar_length=$((progress / 5))
            local bar=$(printf "%${bar_length}s" | tr ' ' '#')
            printf "\rRemoving worktrees: [%-20s] %d%%" "$bar" "$progress"
            
            # Remove the git worktree reference
            if git worktree remove "$worktree" --force 2>/dev/null; then
                ((removed_count++))
            else
                # If git worktree remove fails, try manual cleanup
                if [ -d "$worktree" ]; then
                    rm -rf "$worktree"
                    git worktree prune 2>/dev/null
                    
                    if [ ! -d "$worktree" ]; then
                        ((removed_count++))
                    else
                        ((failed_count++))
                    fi
                else
                    git worktree prune 2>/dev/null
                    ((removed_count++))
                fi
            fi
        fi
    done <<< "$(echo -e "$worktrees_to_remove")"
    
    # Complete the progress bar
    printf "\rRemoving worktrees: [####################] 100%%\n"
    
    # Now remove branches
    echo ""
    printf "Removing branches: "
    
    local branches_removed=0
    local branches_failed=0
    local branch_current=0
    local total_branches=$(echo -e "$branches_to_delete" | grep -c '^[^[:space:]]*$' 2>/dev/null || echo 0)
    
    if [ $total_branches -gt 0 ]; then
        while IFS= read -r branch; do
            if [ -n "$branch" ]; then
                ((branch_current++))
                
                # Calculate and show progress
                local branch_progress=$((branch_current * 100 / total_branches))
                local branch_bar_length=$((branch_progress / 5))
                local branch_bar=$(printf "%${branch_bar_length}s" | tr ' ' '#')
                printf "\rRemoving branches: [%-20s] %d%%" "$branch_bar" "$branch_progress"
                
                # Remove the branch
                if git branch -D "$branch" > /dev/null 2>&1; then
                    ((branches_removed++))
                else
                    ((branches_failed++))
                fi
            fi
        done <<< "$(echo -e "$branches_to_delete")"
        
        # Complete the branch progress bar
        printf "\rRemoving branches: [####################] 100%%\n"
    else
        printf "[####################] 100%%\n"
    fi
    
    echo ""
    if [ $failed_count -gt 0 ] || [ $branches_failed -gt 0 ]; then
        echo "Cleanup complete:"
        echo "  Worktrees: ${removed_count} removed, ${failed_count} failed"
        echo "  Branches: ${branches_removed} removed, ${branches_failed} failed"
    else
        echo "Cleanup complete:"
        echo "  ${removed_count} worktree(s) removed"
        echo "  ${branches_removed} branch(es) removed"
    fi
    
    # Final prune
    git worktree prune 2>/dev/null
}

# Helper function to open terminal
_wt_open_terminal() {
    local worktree_path="$1"
    
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
        fi
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        # Windows
        if command -v wt &> /dev/null; then
            wt -d "$worktree_path" &
        else
            start cmd /c "cd /d ${worktree_path} && bash"
        fi
    fi
}