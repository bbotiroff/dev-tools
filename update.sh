#!/bin/bash

# Dev-Tools Update Script
# This script updates existing dev-tools installations with the latest fixes and improvements

set -e  # Exit on any error

echo "🔧 Dev-Tools Update Script"
echo "========================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
BACKUP_DIR="$HOME/.dev-tools-backup-$(date +%Y%m%d-%H%M%S)"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to backup files
backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        mkdir -p "$BACKUP_DIR"
        cp "$file" "$BACKUP_DIR/$(basename "$file")"
        log_info "Backed up $file to $BACKUP_DIR"
    fi
}

# Function to update git repository
update_repository() {
    log_info "Updating dev-tools repository..."

    if [[ -d "$SCRIPT_DIR/.git" ]]; then
        cd "$SCRIPT_DIR"
        git fetch origin
        local current_branch=$(git branch --show-current)
        git pull origin "$current_branch" || {
            log_warning "Git pull failed, continuing with local files..."
        }
        log_success "Repository updated"
    else
        log_warning "Not a git repository, skipping git update"
    fi
}

# Function to install missing brew packages
install_missing_packages() {
    log_info "Checking for missing brew packages..."

    local packages=("zsh-autosuggestions" "zsh-syntax-highlighting" "zsh-history-substring-search" "zsh-navigation-tools")

    for package in "${packages[@]}"; do
        if ! brew list "$package" &>/dev/null; then
            log_info "Installing missing package: $package"
            brew install "$package"
        else
            log_success "$package is already installed"
        fi
    done
}

# Function to fix zsh configuration
fix_zsh_config() {
    log_info "Fixing zsh configuration..."

    # Backup current ~/.zshrc
    backup_file "$HOME/.zshrc"

    # Remove old broken zsh-autosuggestions line
    if grep -q "source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh" "$HOME/.zshrc" 2>/dev/null; then
        log_info "Removing broken zsh-autosuggestions reference..."
        sed -i.bak '/source ~\/.zsh\/zsh-autosuggestions\/zsh-autosuggestions.zsh/d' "$HOME/.zshrc"
        log_success "Removed broken zsh-autosuggestions reference"
    fi

    # Add brew zsh-autosuggestions if not present
    if ! grep -q "source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" "$HOME/.zshrc" 2>/dev/null; then
        log_info "Adding brew zsh-autosuggestions to ~/.zshrc..."
        echo "source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" >> "$HOME/.zshrc"
        log_success "Added brew zsh-autosuggestions"
    fi
}

# Function to clean up old manual installations
cleanup_old_installations() {
    log_info "Cleaning up old manual installations..."

    if [[ -d "$HOME/.zsh/zsh-autosuggestions" ]]; then
        log_info "Removing old manual zsh-autosuggestions installation..."
        rm -rf "$HOME/.zsh/zsh-autosuggestions"
        log_success "Removed old manual zsh-autosuggestions"
    fi

    # Clean up empty .zsh directory if it exists
    if [[ -d "$HOME/.zsh" ]] && [[ -z "$(ls -A "$HOME/.zsh")" ]]; then
        rmdir "$HOME/.zsh"
        log_success "Removed empty ~/.zsh directory"
    fi
}

# Function to setup Claude Code configuration
setup_claude_code() {
    log_info "Setting up Claude Code configuration..."

    # Check if Claude directory and files exist in the repo
    if [[ ! -d "$SCRIPT_DIR/claude" ]]; then
        log_warning "Claude configuration directory not found in repo, skipping Claude setup"
        return 0
    fi

    # Create .claude directory if it doesn't exist
    mkdir -p "$HOME/.claude"

    # Copy/update statusline script
    if [[ -f "$SCRIPT_DIR/claude/statusline-command.sh" ]]; then
        if [[ -f "$HOME/.claude/statusline-command.sh" ]]; then
            # Check if files are different
            if ! cmp -s "$SCRIPT_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"; then
                backup_file "$HOME/.claude/statusline-command.sh"
                cp "$SCRIPT_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
                chmod +x "$HOME/.claude/statusline-command.sh"
                log_success "Updated Claude Code statusline script"
            else
                log_info "Claude Code statusline script is up to date"
            fi
        else
            cp "$SCRIPT_DIR/claude/statusline-command.sh" "$HOME/.claude/statusline-command.sh"
            chmod +x "$HOME/.claude/statusline-command.sh"
            log_success "Installed Claude Code statusline script"
        fi
    fi

    # Setup/update settings.json
    if [[ -f "$SCRIPT_DIR/claude/settings.json.template" ]]; then
        if [[ -f "$HOME/.claude/settings.json" ]]; then
            # Backup existing settings
            backup_file "$HOME/.claude/settings.json"

            # Try to merge settings using jq if available
            if command -v jq &> /dev/null; then
                # Merge statusline configuration into existing settings
                jq -s '.[0] * .[1]' "$HOME/.claude/settings.json" "$SCRIPT_DIR/claude/settings.json.template" > "$HOME/.claude/settings.json.tmp" 2>/dev/null && {
                    mv "$HOME/.claude/settings.json.tmp" "$HOME/.claude/settings.json"
                    log_success "Updated Claude Code settings (existing settings preserved)"
                } || {
                    rm -f "$HOME/.claude/settings.json.tmp"
                    log_warning "Could not merge settings, please manually add statusline config to ~/.claude/settings.json"
                }
            else
                # Check if statusline is already configured
                if ! grep -q "statuslineCommand" "$HOME/.claude/settings.json" 2>/dev/null; then
                    log_warning "jq not found - please manually add statusline config from $SCRIPT_DIR/claude/settings.json.template"
                else
                    log_info "Claude Code settings already has statusline configured"
                fi
            fi
        else
            # No existing settings, just copy template
            cp "$SCRIPT_DIR/claude/settings.json.template" "$HOME/.claude/settings.json"
            log_success "Created Claude Code settings with statusline configuration"
        fi
    fi
}

# Function to validate installation
validate_installation() {
    log_info "Validating installation..."

    local issues=0

    # Check if BBOTIROFF_DEV_TOOL_PATH is set correctly
    if [[ -z "$BBOTIROFF_DEV_TOOL_PATH" ]]; then
        log_warning "BBOTIROFF_DEV_TOOL_PATH is not set in current session"
        ((issues++))
    fi

    # Check if main files exist
    local files=("$SCRIPT_DIR/zsh/.zshrc" "$SCRIPT_DIR/git-shortcuts.sh" "$SCRIPT_DIR/worktree-cli.sh")
    for file in "${files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Missing file: $file"
            ((issues++))
        fi
    done

    # Check brew packages
    local packages=("zsh-autosuggestions" "zsh-syntax-highlighting")
    for package in "${packages[@]}"; do
        if ! brew list "$package" &>/dev/null; then
            log_error "Missing brew package: $package"
            ((issues++))
        fi
    done

    # Check Claude Code setup if directory exists
    if [[ -d "$SCRIPT_DIR/claude" ]]; then
        if [[ ! -f "$HOME/.claude/statusline-command.sh" ]]; then
            log_warning "Claude Code statusline script not installed"
            ((issues++))
        elif [[ ! -x "$HOME/.claude/statusline-command.sh" ]]; then
            log_warning "Claude Code statusline script not executable"
            ((issues++))
        fi

        if [[ ! -f "$HOME/.claude/settings.json" ]]; then
            log_warning "Claude Code settings not configured"
            ((issues++))
        fi
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "Installation validation passed"
        return 0
    else
        log_warning "Found $issues issues during validation"
        return 1
    fi
}

# Main update process
main() {
    log_info "Starting dev-tools update process..."
    echo

    # Step 1: Update repository
    update_repository
    echo

    # Step 2: Install missing packages
    install_missing_packages
    echo

    # Step 3: Fix zsh configuration
    fix_zsh_config
    echo

    # Step 4: Clean up old installations
    cleanup_old_installations
    echo

    # Step 5: Setup Claude Code configuration
    setup_claude_code
    echo

    # Step 6: Validate installation
    validate_installation
    echo

    log_success "Dev-tools update completed!"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Restart your terminal or run: source ~/.zshrc"
    echo "2. Verify everything works correctly"

    if [[ -d "$BACKUP_DIR" ]]; then
        echo "3. If everything works, you can remove backup: rm -rf $BACKUP_DIR"
    fi

    echo
    echo -e "${GREEN}🎉 Update complete!${NC}"
}

# Check if running as part of another script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi