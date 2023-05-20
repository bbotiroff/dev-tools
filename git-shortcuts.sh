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

gswitch() {
  git switch $1
}

gallc() {
    git add .
    git commit -m $1
}

# Delete all local branches except, develop, dev, staging, master, and the current branch
gdeletebranches() {
    git branch | grep -v ^* |  grep -v "develop" | grep -v "dev" | grep -v "staging" | grep -v "master" | grep -v "main" | xargs git branch -D
}

