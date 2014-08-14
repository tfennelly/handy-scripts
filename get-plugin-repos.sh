#!/bin/bash

# Before calling this script, you need to set your Github username
# and password in the env e.g.:
# export GITHUB_UN=<username>
# export GITHUB_PW=<password>

# Use curl -i https://api.github.com/orgs/jenkinsci/repos?page=XXX
# to test for how many pages can be returned from the API.
# After working that out, update the following variable.
NUM_REPO_PAGES=42

# delete the repo url list file
rm repourls.txt

# recreate the repo url list file
for i in `seq 1 $NUM_REPO_PAGES`;
do
  echo "Getting page $i"
  curl -u $GITHUB_UN:$GITHUB_PW https://api.github.com/orgs/jenkinsci/repos?page=$i | grep clone_url  | sed 's/    "clone_url": "\(.*\)",/\1/g' >> repourls.txt
done

rm -rf repos

# clone all the repos listed in the repo url list file
mkdir repos
pushd repos
cat ../repourls.txt | while read giturl; do git clone "$giturl"; done
popd
