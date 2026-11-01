#!/bin/bash
# Set up a new project from template/:
#
#   ./new-project.sh ~/code/my_project
#
# The directory may already exist (e.g. a fresh git clone); it only must not
# already have .devcontainer, .claude, CLAUDE.md or hooks.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)

if [ $# -ne 1 ]; then
    echo "usage: $0 <project-dir>" >&2
    exit 1
fi

dest=$1
for d in .devcontainer .claude CLAUDE.md hooks; do
    if [ -e "$dest/$d" ]; then
        echo "$dest/$d already exists; not overwriting it." >&2
        exit 1
    fi
done

mkdir -p "$dest"
dest=$(cd "$dest" && pwd)
name=$(basename "$dest")

cp -R "$here/template/." "$dest/"

f="$dest/.devcontainer/devcontainer.json"
filled=$(sed -e "s|__PROJECT_NAME__|$name|g" "$f")
printf '%s\n' "$filled" > "$f"

echo "Created $name. Open $dest in VS Code and choose \"Reopen in Container\"."
