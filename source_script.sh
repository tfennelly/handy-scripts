#!/usr/bin/env bash

script_url=$1
if [ -z "$script_url" ]; then
  echo "Usage: source_script.sh <URL>"
  exit 1
fi

nowts=$(date +%s)
temp_file=$(mktemp "script_temp.${nowts}.sh")

curl -o "$temp_file" "$script_url"
source "$temp_file"
rm "$temp_file"