#!/usr/bin/env bash
# Link the canonical skills in ~/.agents/skills into every harness root on this
# machine. Idempotent: safe to re-run after editing any skill.
#
# Windows notes, all learned the hard way:
#   - `ln -s` under MSYS can silently produce a directory COPY instead of a
#     link, so every link is verified with `-L` afterwards and rolled back.
#   - `cmd /c mklink /D` needs elevation or Developer Mode; a junction
#     (`mklink /J`) does not, and Git Bash reads a junction as a symlink.
#   - a junction is removed with `rmdir`, never `rm -rf`, which fails on it and
#     must never be pointed at something that resolves into the canonical tree.
# The working mechanism is probed once and cached, because each `cmd` call
# costs seconds.
set -uo pipefail

CANON="$HOME/.agents/skills"
ROOTS=("$HOME/.claude/skills" "$HOME/.pi/agent/skills")
SKILLS=(steer implement)
MARKER=.steer-install-copy

win_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1" | sed 's|/|\\|g'
  fi
}

# Remove a link without ever recursing into what it points at.
remove_link() {
  local p="$1"
  [ -e "$p" ] || [ -L "$p" ] || return 0
  rmdir "$p" 2>/dev/null && return 0
  rm -f "$p" 2>/dev/null && return 0
  [ -L "$p" ] && return 1 # still a link: refuse to rm -rf it
  rm -rf "$p" 2>/dev/null
}

win_mklink() { # <flag> <target> <source>
  command -v cmd >/dev/null 2>&1 || return 1
  MSYS_NO_PATHCONV=1 cmd /c mklink "$1" "$(win_path "$2")" "$(win_path "$3")" >/dev/null 2>&1 &&
    [ -L "$2" ]
}

WIN_MODE=unprobed # unprobed | /D | /J | none

probe_win_mode() {
  [ "$WIN_MODE" = unprobed ] || return 0
  local probe="${ROOTS[0]}/.steer-link-probe"
  remove_link "$probe"
  local flag
  for flag in /D /J; do
    if win_mklink "$flag" "$probe" "$CANON"; then
      remove_link "$probe"
      WIN_MODE="$flag"
      return 0
    fi
    remove_link "$probe"
  done
  WIN_MODE=none
}

# make_link <target> <source-dir>; sets LINK_HOW. Never run in a subshell: the
# probe cache and LINK_HOW both have to survive the call.
LINK_HOW=
make_link() {
  local target="$1" source="$2"
  LINK_HOW=

  if MSYS=winsymlinks:nativestrict ln -s "$source" "$target" 2>/dev/null; then
    if [ -L "$target" ]; then
      LINK_HOW=symlink
      return 0
    fi
    rm -rf "$target" # MSYS made a copy, not a link
  fi

  probe_win_mode
  if [ "$WIN_MODE" != none ] && win_mklink "$WIN_MODE" "$target" "$source"; then
    [ "$WIN_MODE" = /J ] && LINK_HOW=junction || LINK_HOW=symlink
    return 0
  fi
  remove_link "$target"

  if cp -R "$source" "$target" 2>/dev/null; then
    : >"$target/$MARKER"
    LINK_HOW=copy
    return 0
  fi
  return 1
}

same_target() {
  [ -e "$1" ] || return 1
  [ "$(readlink -f "$1" 2>/dev/null)" = "$(readlink -f "$2" 2>/dev/null)" ]
}

# A directory this script previously copied, or a content-equal duplicate of
# the canonical skill (line endings ignored). Either is ours to replace.
replaceable() {
  local target="$1" source="$2"
  [ -f "$target/$MARKER" ] && return 0
  diff -r --strip-trailing-cr --exclude="$MARKER" "$source" "$target" >/dev/null 2>&1
}

copies_made=0

install_skill() {
  local name="$1" root="$2"
  local source="$CANON/$name" target="$root/$name"

  if [ ! -d "$source" ]; then
    echo "SKIP  $target — no canonical $source"
    return
  fi

  if [ -L "$target" ]; then
    if same_target "$target" "$source"; then
      echo "OK    $target — already links to canonical"
      return
    fi
    remove_link "$target" || {
      echo "WARN  $target is a link elsewhere and could not be removed — left alone"
      return
    }
  elif [ -d "$target" ]; then
    if replaceable "$target" "$source"; then
      rm -rf "$target"
    else
      echo "WARN  $target differs from canonical — left alone, reconcile by hand"
      return
    fi
  elif [ -e "$target" ]; then
    echo "WARN  $target exists and is not a directory — left alone"
    return
  fi

  if make_link "$target" "$source"; then
    echo "LINK  $target -> $source ($LINK_HOW)"
    [ "$LINK_HOW" = copy ] && copies_made=1
  else
    echo "FAIL  $target — could not link or copy"
  fi
}

for root in "${ROOTS[@]}"; do
  if [ ! -d "$root" ]; then
    echo "SKIP  $root — harness root not present"
    continue
  fi
  for name in "${SKILLS[@]}"; do
    install_skill "$name" "$root"
  done
done

if [ "$copies_made" = 1 ]; then
  echo
  echo "NOTE  At least one root got a COPY, not a link: no link mechanism was"
  echo "      available. Re-run this script after every edit to a canonical"
  echo "      skill, or enable Windows Developer Mode so 'mklink' succeeds."
fi
