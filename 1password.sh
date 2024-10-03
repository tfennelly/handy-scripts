#!/usr/bin/env bash

# https://gist.github.com/vratiu/9780109
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

op --version > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo -e "\n${RED}Error: 1password CLI is not installed. Go to https://developer.1password.com/docs/cli and install.${NC}"
  exit 1
else
  echo -e "\n${GREEN}1password CLI is installed.${NC}"
fi

function login1Password() {
  echo ''
  echo '********************************************************************************'
  echo 'We need to login to 1password (via the 1password CLI) to get the'
  echo "secrets from the '$VAULT_NAME' 1Password vault."
  echo ''
  echo 'You will need your 1password "Password".'
  echo '********************************************************************************'
  echo ''
  
  accountName=$1
  if [ -z "$accountName" ]; then
    echo -e "\n${RED}Error: You must provide the 1Password account name.${NC}"
    exit 1
  fi

  eval $(op signin --account "$accountName")
  if [ $? -ne 0 ]; then
    echo -e "\n${RED}Error fetching secrets from the '$VAULT_NAME' 1Password vault. You may need to request access.${NC}"
    exit 1
  fi

  echo -e "\n${GREEN}Successfully logged in to 1Password account '$accountName' ${NC}"
}

echo -e "\n${GREEN}1password.sh script loaded.${NC}"