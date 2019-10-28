#!/bin/bash

bbotiroffProfileFullPath="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

setBBotiroffBashProfile() {
  profileString="source $bbotiroffProfileFullPath/bbotiroff-profile.sh"
  
  touch ~/.bash_profile

  if ! grep -q "$profileString" ~/.bash_profile ; then 
    echo $profileString >> ~/.bash_profile
  fi
}

installBrew() {
  if ! brew -v ; then 
    /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
  fi
}

setBBotiroffBashProfile
installBrew

# TODO: script to install vscode, nodejs

echo "dev-tools are installed. Please reopen your terminal!"