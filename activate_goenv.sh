#!/bin/bash

set -e
[ "${DEBUG}" == "1" ] && set -x
set -u
set -o pipefail
set -v

# Initialize prev_dir to something; could also use `pwd` here
prev_dir=""

function switch_go_version_based_on_file() {
  current_dir=$(pwd)
  
  # Check if the directory has changed
  if [ "$current_dir" != "$prev_dir" ]; then
    prev_dir="$current_dir"  # Update prev_dir to the new current directory
    
    # Check if we are inside the "/go/projects" directory
    if [[ "$current_dir" == "/go/projects"* ]]; then
      
      # Look for .go_version file and switch version
      if [ -f ".go_version" ]; then
        go_version=$(cat .go_version)
        switchgo "$go_version"
      fi
    fi
  fi
}

# Add the function to PROMPT_COMMAND, preserving existing PROMPT_COMMAND
PROMPT_COMMAND="switch_go_version_based_on_file; $PROMPT_COMMAND"

