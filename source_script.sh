#!/usr/bin/env bash

echo "source_script.sh start"

script_url=$1
if [ -z "$script_url" ]; then
  echo "Usage: source_script.sh <URL>"
  exit 1
fi

nowts=$(date +%s)
temp_file=$(mktemp "script_temp.${nowts}.sh")

echo "Downloading script from $script_url to $temp_file..."
curl -s -o "$temp_file" "$script_url"
echo "Sourcing script..."
source "$temp_file"
rm "$temp_file"