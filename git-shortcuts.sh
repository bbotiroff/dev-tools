#!/bin/bash

parse_current_branch() {
  git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ (\1)/'
}

gpush() {
  git push --set-upstream origin $(git branch | grep \* | cut -d ' ' -f2)
}

gnb() {
  git switch -c $1 
}

gnbb() {
  git switch -c bbotirov/$1 
}

gs() {
  git status
}

gd() {
  git diff
}

gb() {
  git branch
}

gbs() {
  exists=$(gb | grep -w $1)

  if [ -n "$exists" ] ; 
  then git switch $1
  else gnb $1
  fi
}

gcall() {
    git add .
    git commit -m $1
}

# Delete all local branches except, develop, dev, staging, master, and the current branch
gdeletebranches() {
    git branch | grep -v ^* |  grep -v "develop" | grep -v "dev" | grep -v "staging" | grep -v "master" | grep -v "main" | xargs git branch -D
}

# Delete ALL local branches except main, master, and the current branch (asks to confirm)
gbclean() {
  local targets
  targets=$(git branch | grep -v '^[*+]' | sed 's/^ *//' | grep -vxE 'main|master')

  if [ -z "$targets" ]; then
    echo "No branches to delete."
    return 0
  fi

  echo "The following local branches will be force-deleted:"
  echo "$targets" | sed 's/^/  /'
  printf "Proceed? (y/N) "
  read -r reply
  case "$reply" in
    [yY]|[yY][eE][sS])
      echo "$targets" | xargs git branch -D
      ;;
    *)
      echo "Aborted."
      ;;
  esac
}

# starts the maintenance on the repository
gmmaintenance() {
  git maintenance start
}
