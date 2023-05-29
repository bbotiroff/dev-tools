#!/bin/bash

bbotiroffProfileFullPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

setBBotiroffBashProfile() {
  profileString="source $bbotiroffProfileFullPath/bbotiroff-profile.sh"
  
  touch ~/.bash_profile

  if ! grep -q "$profileString" ~/.bash_profile ; then 
    echo "export BBOTIROFF_DEV_TOOL_PATH=$bbotiroffProfileFullPath" >> ~/.zshrc
    echo $profileString >> ~/.bash_profile
  fi
}

setBBotiroffZshProfile() {
  profileString="source $bbotiroffProfileFullPath/zsh/.zshrc"

  touch ~/.zshrc

  if ! grep -q "$profileString" ~/.zshrc ; then 
    echo "export BBOTIROFF_DEV_TOOL_PATH=$bbotiroffProfileFullPath" >> ~/.zshrc
    echo $profileString >> ~/.zshrc
    
    /bin/zsh git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions

    # Installing syntax highlighting - this has to be at the end of the file
    /bin/zsh brew install zsh-syntax-highlighting
    echo "source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
  fi
}

installBrew() {
  if ! type "brew" > /dev/null 2>&1 ; then 
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"
  fi
  
  if [ -z "${ZSH_VERSION+x}" ]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zshrc
  fi

  if [ -z "${BASH_VERSION+x}" ]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.bash_profile
  fi

  /bin/zsh brew install --cask visual-studio-code
  /bin/zsh brew install --cask docker
  /bin/zsh brew install --cask postman
  /bin/zsh brew install --cask another-redis-desktop-manager
  /bin/zsh brew install --cask tableplus
  /bin/zsh brew install --cask powershell
}

installBrew
setBBotiroffBashProfile
setBBotiroffZshProfile

# TODO: script to install vscode, nodejs
export PATH="$PATH:/Applications/Rider.app/Contents/MacOS"
echo "dev-tools are installed. Please reopen your terminal!"