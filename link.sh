#!/usr/bin/env bash
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/nvim"

mkdir -p "$config_dir" "$HOME/.vim/undo"

link() {
  local src="$1" dest="$2"
  if [ ! -e "$src" ]; then
    return
  fi
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "skip: $dest exists and is not a symlink" >&2
    return
  fi
  ln -sfn "$src" "$dest"
}

for name in init.lua .vimrc lua lsp colors nvim-pack-lock.json; do
  link "$repo/$name" "$config_dir/$name"
done

link "$repo/.vimrc" "$HOME/.vimrc"

echo "linked $repo into $config_dir"
