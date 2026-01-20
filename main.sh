#!/usr/bin/bash

projects_txt=~/.local/share/pj/projects.txt
# Get the directory of the current script
SCRIPT_DIR=$(dirname "${BASH_SOURCE[0]}")
# Convert to an absolute path
SCRIPT_DIR=$(realpath "$SCRIPT_DIR")
docs_file=$SCRIPT_DIR/docs.txt

# create projects.txt if it doesn't exist
if ! [ -d "$(dirname "$projects_txt")" ]; then
  mkdir -p "$(dirname "$projects_txt")"
  touch "$projects_txt"
fi

# activate venv
av() {
  if [ -d ".venv" ]; then
    source .venv/bin/activate
    echo "Activated ${VIRTUAL_ENV}"
  elif [ -d "venv" ]; then
    source venv/bin/activate
    echo "Activated ${VIRTUAL_ENV}"
  fi
  return
}

pj() {
  # if no arguments given, interactively select the project with fzf
  if [ $# -eq 0 ]; then
    target_line=$(sed "s/:::.*//" "$projects_txt" | fzf --scheme=history | xargs -I {} grep "^{}:::" $projects_txt)
    target_dir=${target_line##*:::}
    # if operation cancelled
    if [ -z "$target_dir" ]; then
      return 0
    fi
    # Move the selected line to the top of projects_txt
    tmpfile=$(mktemp)
    grep -vFx "$target_line" "$projects_txt" >"$tmpfile"
    echo "$target_line" >"$projects_txt"
    cat "$tmpfile" >>"$projects_txt"
    rm "$tmpfile"
    # if venv is active, deactivate it
    if [ -n "${VIRTUAL_ENV}" ]; then
      deactivate
    fi
    # switch to the new directory and activate the venv, return on failure
    cd "$target_dir" || return
    av
    return
  else
    while (("$#")); do
      case "$1" in
      -h | --help | help)
        cat "$docs_file" | less
        return
        ;;
      -a | --add)
        # if a project name is supplied (can't start with a '-')
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          matches=$(grep -c "^${2}:::" "$projects_txt")
          if [ "$matches" -gt 0 ]; then
            echo "A project with this name is already defined"
            return 1
          else
            echo "${2}:::$(pwd)" >>"$projects_txt"
          fi
        else
          # no project name supplied so use CWD basename
          matches=$(grep -c "^$(basename "$(pwd)"):::" "$projects_txt")
          if [ "$matches" -gt 0 ]; then
            echo "A project with this name is already defined"
            return 1
          else
            echo "$(basename "$(pwd)"):::$(pwd)" >>"$projects_txt"
          fi
        fi
        echo "new project added"
        return
        ;;
      -r | -d | --remove)
        # if a project name is given (can't start with a '-')
        if [ -n "$2" ] && [ "${2:0:1}" != "-" ]; then
          matches=$(grep -c "^${2}:::" "$projects_txt")
          if [ "$matches" -ne 1 ]; then
            echo "unable to determine project"
            return 1
          fi
          sed -i "/^${2}:::.*/d" "$projects_txt"
        else
          # no project name given, do interactive selection with fzf
          target_project=$(sed "s/:::.*//" "$projects_txt" | fzf --scheme=history)
          if [ -z "$target_project" ]; then
            # no selection made
            return 0
          else
            sed -i "/^$target_project:::/d" "$projects_txt"
          fi
        fi
        echo "project deleted"
        return
        ;;
      -l | --list)
        sed "s/:::.*//" "$projects_txt"
        return
        ;;
      -e | --edit)
        if [ -z "$EDITOR" ]; then
          xdg-open "$projects_txt"
        else
          $EDITOR "$projects_txt"
        fi
        return
        ;;
      -c | --clean)
        temp_file=$(mktemp)
        # Loop through each line in projects.txt
        while IFS= read -r line; do
          # Extract directory path
          dir_path=${line/*:::/}
          project_name=${line/:::*/}
          # Check if directory exists
          if [ -d "$dir_path" ]; then
            echo "$line" >>"$temp_file"
          else
            echo "cleaning $project_name"
          fi
        done <"$projects_txt"
        new=$(wc -l <"$temp_file")
        old=$(wc -l <"$projects_txt")
        difference=$((old - new))
        if [ "$difference" -gt 0 ]; then
          echo "cleaned $difference projects"
        else
          echo "no projects to clean"
        fi
        # Move temp_file to overwrite projects.txt
        mv "$temp_file" "$projects_txt"
        return
        ;;
      -u | --unpushed)
        # Loop through each line in projects.txt
        current_dir=$(pwd)
        allpushed=yes
        while IFS= read -r line; do
          # Extract directory path
          dir_path=${line/*:::/}
          project_name=${line/:::*/}
          # Check if directory exists
          if [ -d "$dir_path" ]; then
            cd "$dir_path" || return
            if [ -d ".git" ]; then
              # Check for unpushed commits
              msg="$(git cherry -v 2>/dev/null)"
              if ! [ $? = 0 ]; then
                echo "$project_name ($(git branch --show-current)) has no upstream"
              elif [ "$msg" ]; then
                echo "$project_name has unpushed commits:"
                echo "$msg"
                allpushed=no
              fi
              # Check for dirty worktree (uncommitted changes)
              if [ -n "$(git status --porcelain)" ]; then
                echo "$project_name has a dirty worktree (uncommitted changes)"
                allpushed=no
              fi
            fi
          fi
        done <"$projects_txt"
        if [ "$allpushed" == "yes" ]; then
          echo "no unpushed commits"
        fi
        cd "$current_dir" || return
        return
        ;;
      -*)
        echo "invalid flags"
        return 1
        ;;
      *)
        # search for project to switch to using supplied args
        project_line=$(grep "^${1}.*:::" "$projects_txt")
        matches=$(echo "$project_line" | wc -l)
        if [ "$matches" -ne 1 ]; then
          echo "unable to determine project"
          return 1
        fi
        # Move the selected line to the top (recency bonus)
        tmpfile=$(mktemp)
        grep -vFx "$project_line" "$projects_txt" >"$tmpfile"
        echo "$project_line" >"$projects_txt"
        cat "$tmpfile" >>"$projects_txt"
        rm "$tmpfile"
        # Extract directory using Bash substring
        pj_dir=${project_line##*::}
        if [ -n "${VIRTUAL_ENV}" ]; then
          deactivate
        fi
        cd "$pj_dir" || return
        av
        return
        ;;
      esac
    done
  fi
}
complete -W "$(sed "s/:::.*//" "$projects_txt")" pj
