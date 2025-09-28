#!/bin/bash

bbotiroffProfileFullPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

setBBotiroffBashProfile() {
  profileString="source $bbotiroffProfileFullPath/bbotiroff-profile.sh"
  
  touch ~/.bash_profile

  if ! grep -q "$profileString" ~/.bash_profile 2>/dev/null ; then
    echo "export BBOTIROFF_DEV_TOOL_PATH=$bbotiroffProfileFullPath" >> ~/.bash_profile
    echo $profileString >> ~/.bash_profile
  fi
}

setBBotiroffZshProfile() {
  profileString="source $bbotiroffProfileFullPath/zsh/.zshrc"

  touch ~/.zshrc
  mkdir -p ~/Workspace

  if ! grep -q "$profileString" ~/.zshrc 2>/dev/null ; then 
    echo "export BBOTIROFF_DEV_TOOL_PATH=$bbotiroffProfileFullPath" >> ~/.zshrc
    echo $profileString >> ~/.zshrc
    
    # Installing zsh plugins - these have to be at the end of the file
    brew install zsh-history-substring-search
    brew install zsh-autosuggestions
    brew install zsh-syntax-highlighting
    brew install zsh-navigation-tools

    echo "source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc
    echo "source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
    echo "source /opt/homebrew/share/zsh-history-substring-search/zsh-history-substring-search.zsh" >> ~/.zshrc
    echo "source /opt/homebrew/share/zsh-navigation-tools/zsh-navigation-tools.plugin.zsh" >> ~/.zshrc
  fi
}

installBrew() {
  if ! type "brew" > /dev/null 2>&1 ; then 
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi
  
  if [ -n "${ZSH_VERSION+x}" ]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
  fi

  if [ -n "${BASH_VERSION+x}" ]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
  fi

  brew install kubectx
  brew install awscli
  brew install awscli-local
  brew install minikube
  brew install helm
  brew install azure-cli
  brew install jq
  brew install k9s
  brew install node
  brew install nodenv

  brew install --cask visual-studio-code
  brew install --cask docker
  brew install --cask postman
  brew install --cask another-redis-desktop-manager
  brew install --cask powershell
  brew install --cask 1password
  brew install --cask google-chrome
  brew install --cask claude-code
  brew install --cask mongodb-compass
}

setupClaudeCode() {
  echo "Setting up Claude Code configuration..."

  # Create .claude directory if it doesn't exist
  mkdir -p ~/.claude

  # Copy statusline script
  if [ -f "$bbotiroffProfileFullPath/claude/statusline-command.sh" ]; then
    cp "$bbotiroffProfileFullPath/claude/statusline-command.sh" ~/.claude/statusline-command.sh
    chmod +x ~/.claude/statusline-command.sh
    echo "✓ Claude Code statusline script installed"
  fi

  # Setup settings.json
  if [ -f "$bbotiroffProfileFullPath/claude/settings.json.template" ]; then
    # Check if settings.json exists
    if [ -f ~/.claude/settings.json ]; then
      # Backup existing settings
      cp ~/.claude/settings.json ~/.claude/settings.json.backup

      # Merge statusline configuration into existing settings using jq
      if command -v jq &> /dev/null; then
        jq -s '.[0] * .[1]' ~/.claude/settings.json "$bbotiroffProfileFullPath/claude/settings.json.template" > ~/.claude/settings.json.tmp
        mv ~/.claude/settings.json.tmp ~/.claude/settings.json
        echo "✓ Claude Code settings updated (existing settings preserved)"
      else
        echo "⚠ jq not found, manually add statusline config to ~/.claude/settings.json"
      fi
    else
      # No existing settings, just copy template
      cp "$bbotiroffProfileFullPath/claude/settings.json.template" ~/.claude/settings.json
      echo "✓ Claude Code settings created"
    fi
  fi

  echo "✓ Claude Code setup complete!"
}

installBrew
setBBotiroffBashProfile
setBBotiroffZshProfile
setupClaudeCode

# TODO: script to install vscode, nodejs
export PATH="$PATH:/Applications/Rider.app/Contents/MacOS"
echo "dev-tools are installed. Please reopen your terminal!"