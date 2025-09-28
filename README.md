# 🛠️ Dev-Tools

A comprehensive macOS development environment setup with enhanced shell features, git workflow improvements, and modern developer tooling.

## 📋 Table of Contents

- [Overview](#overview)
- [⚠️ Important: Installation Location](#️-important-installation-location)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Updating](#updating)
- [Features](#features)
- [Command Reference](#command-reference)
- [What Gets Installed](#what-gets-installed)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

Dev-Tools is a curated collection of shell enhancements, git shortcuts, and development utilities designed to supercharge your macOS development workflow. It provides:

- ⚡ **Lightning-fast git operations** with smart shortcuts
- 🌳 **Advanced worktree management** for parallel development
- 🎨 **Beautiful, informative shell prompts** with git integration
- 🤖 **Claude Code integration** with custom status line
- 📦 **One-command installation** of essential dev tools
- 🔄 **Smart update system** with automatic backups

## ⚠️ Important: Installation Location

> **CRITICAL**: This project **MUST** be cloned to `~/Workspace/dev-tools`

The installation scripts and shell configurations are hardcoded to expect the dev-tools in this exact location. Installing elsewhere will cause the setup to fail.

```bash
# ✅ CORRECT location
~/Workspace/dev-tools

# ❌ WRONG locations
~/dev-tools
~/Documents/dev-tools
/usr/local/dev-tools
```

## Prerequisites

- macOS (Intel or Apple Silicon)
- Admin access (for Homebrew installation)
- Git installed
- Terminal access (Terminal.app, iTerm2, or similar)

## Installation

### Fresh Installation

1. **Create the Workspace directory** (if it doesn't exist):
   ```bash
   mkdir -p ~/Workspace
   ```

2. **Clone the repository to the CORRECT location**:
   ```bash
   cd ~/Workspace
   git clone https://github.com/bbotiroff/dev-tools.git
   cd dev-tools
   ```

3. **Run the installation script**:
   ```bash
   bash install.sh
   ```

4. **Restart your terminal** or source your profile:
   ```bash
   source ~/.zshrc
   ```

The installation will:
- Install Homebrew (if not present)
- Install CLI tools and applications
- Configure your shell with enhancements
- Set up git shortcuts and worktree management
- Configure Claude Code (if installed)

## Updating

### For Existing Installations

If you already have dev-tools installed and want to apply the latest updates:

#### Option 1: Quick Update (Recommended)
```bash
devtools-update
# or use the short alias
dtu
```

#### Option 2: Manual Update
```bash
cd ~/Workspace/dev-tools
bash update.sh
```

The update process will:
- ✅ Pull latest changes from git
- ✅ Install any missing packages
- ✅ Fix configuration issues
- ✅ Create backups before making changes
- ✅ Validate the installation

## Features

### 🚀 Git Shortcuts

Enhanced git workflow with smart commands:

| Command | Description |
|---------|-------------|
| `gs` | Git status |
| `gb` | Git branch list |
| `gd` | Git diff |
| `gpush` | Push current branch with upstream |
| `gnb <name>` | Create and switch to new branch |
| `gnbb <name>` | Create branch with "bbotirov/" prefix |
| `gbs <name>` | Smart branch switch (create if doesn't exist) |
| `gcall <msg>` | Add all files and commit |
| `gdeletebranches` | Delete all local branches except main ones |

### 🌳 Worktree CLI

Advanced git worktree management with the `wt` command:

| Command | Description |
|---------|-------------|
| `wt add <name>` | Create new worktree with full project copy |
| `wt list` | List all active worktrees |
| `wt rm <name>` | Remove specific worktree |
| `wt clean` | Remove ALL worktrees (use with caution!) |
| `wt help` | Show worktree help |

**Features:**
- Automatically opens new terminal in worktree
- Copies all files including .gitignore'd ones
- Progress indicators for all operations
- Cross-platform terminal support

### ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|---------|
| `Ctrl+G` | Navigate to ~/Workspace |
| `Option+Enter` | Insert newline without executing |

### 🎨 Shell Enhancements

- **Git-aware prompt** showing branch and dirty state
- **Colored output** for ls, grep, and man pages
- **Enhanced tab completion** with visual styling
- **10,000 command history** with search
- **Base64 utilities** (`baseen`/`basede`)

### 🤖 Claude Code Integration

Custom statusline showing:
- Token usage and context percentage
- Current git branch
- Session information
- Model details

### 🔧 Development Tools

Quick access to tools:

| Alias | Description |
|-------|-------------|
| `devtool` | Open dev-tools in VS Code |
| `k` | kubectl shortcut |
| `dcup` | docker-compose up |
| `dcupd` | docker-compose up -d |
| `ll` | Detailed list with hidden files |

## Command Reference

### Complete Git Functions

| Function | Usage | Description |
|----------|-------|-------------|
| `parse_git_branch()` | Automatic | Shows git branch in prompt |
| `gpush()` | `gpush` | Push with upstream tracking |
| `gnb()` | `gnb feature-x` | Create and switch branch |
| `gnbb()` | `gnbb feature-x` | Create bbotirov/feature-x |
| `gs()` | `gs` | Git status |
| `gd()` | `gd` | Git diff |
| `gb()` | `gb` | List branches |
| `gbs()` | `gbs main` | Smart branch switch |
| `gcall()` | `gcall "message"` | Add all and commit |
| `gdeletebranches()` | `gdeletebranches` | Clean local branches |

### Utility Functions

| Function | Usage | Description |
|----------|-------|-------------|
| `baseen()` | `baseen "text"` | Base64 encode |
| `basede()` | `basede "encoded"` | Base64 decode |
| `find_man()` | `find_man ls "sort"` | Search man pages |
| `devtools-update()` | `devtools-update` | Update dev-tools |

## What Gets Installed

### CLI Tools
- `kubectx` - Kubernetes context switcher
- `awscli` - AWS command line interface
- `minikube` - Local Kubernetes
- `helm` - Kubernetes package manager
- `azure-cli` - Azure CLI
- `jq` - JSON processor
- `k9s` - Kubernetes CLI UI
- `node` & `nodenv` - Node.js management

### Applications
- Visual Studio Code
- Docker Desktop
- Postman
- Another Redis Desktop Manager
- PowerShell
- 1Password
- Google Chrome
- Claude Code
- MongoDB Compass

### Zsh Plugins
- `zsh-autosuggestions` - Fish-like autosuggestions
- `zsh-syntax-highlighting` - Syntax highlighting
- `zsh-history-substring-search` - History search
- `zsh-navigation-tools` - Navigation utilities

## Troubleshooting

### Common Issues

**Issue: Command not found after installation**
```bash
source ~/.zshrc
```

**Issue: Worktree commands not working**
- Ensure you're in a git repository
- Check that you have at least one commit

**Issue: Update fails with git errors**
- Commit or stash your local changes
- Run `git status` in ~/Workspace/dev-tools

**Issue: Zsh plugins not working**
```bash
brew reinstall zsh-autosuggestions zsh-syntax-highlighting
source ~/.zshrc
```

### Validation

Check if everything is installed correctly:
```bash
cd ~/Workspace/dev-tools
bash update.sh  # This includes validation
```

### Manual Cleanup

If you need to remove old installations:
```bash
rm -rf ~/.zsh/zsh-autosuggestions
```

## Contributing

1. Fork the repository
2. Create a feature branch (`gnb your-feature`)
3. Make your changes
4. Test with `bash update.sh`
5. Commit your changes (`gcall "Add feature"`)
6. Push to your fork (`gpush`)
7. Create a Pull Request

### For Team Members

To deploy updates to the team:
1. Push changes to main branch
2. Notify team to run `devtools-update` or `dtu`
3. Updates are applied automatically with backups

## License

This project is for internal use. Please consult with the team before sharing externally.

## Support

For issues or questions:
- Check the [Troubleshooting](#troubleshooting) section
- Run validation: `bash ~/Workspace/dev-tools/update.sh`
- Contact the development team

---

**Remember**: Always clone to `~/Workspace/dev-tools` for proper functionality! 🎯