#!/bin/bash

# Before calling this script, you need to set your Github username and password in the env e.g.:
# export GITHUB_UN=<username>
# export GITHUB_PW=<password>
#
# Auth is needed, otherwise you run into rate limits: https://developer.github.com/v3/#rate-limiting

if [ "$GITHUB_UN" == "" ]; then
  echo "Variable 'GITHUB_UN' (Github username) not set in environment.  Please export."
  exit
fi
if [ "$GITHUB_PW" == "" ]; then
  echo "Variable 'GITHUB_PW' (Github password) not set in environment.  Please export."
  exit
fi

# delete the repo url list file
rm repourls.txt

# recreate the repo url list file
for i in `seq 1 1000`;
do
  gitpage=$(curl -u $GITHUB_UN:$GITHUB_PW https://api.github.com/orgs/jenkinsci/repos?page=$i)
  repourls=$(echo "$gitpage" | grep clone_url  | sed 's/    "clone_url": "\(.*\)",/\1/g')

  echo "$repourls" >> repourls.txt

  if [ "$repourls" == "" ]; then
    echo "No results for page $i.  We're done!"
    break
  fi
done	

# clone/update all the repos listed in the repo url list file
if [[ ! -d repos ]]; then
  mkdir repos
fi
pushd repos

while read giturl; do
  repoName=$(echo "$giturl" | sed 's/https\:\/\/github\.com\/jenkinsci\/\(.*\)\.git/\1/')

  if [ "$repoName" == "" ]; then
    continue
  fi

  if [[ -d $repoName ]]; then
    echo "'$repoName' exists ... updating"
    cd $repoName
    git pull origin master
    cd ..
  else
    echo "'$repoName' doesn't exist ... cloning"
    git clone $giturl
  fi

done < ../repourls.txt

echo "FINISHED"

popd
