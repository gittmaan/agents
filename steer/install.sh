#!/usr/bin/env bash
# Install steer and the skills it hands work to.
#
#   1. steer itself: this script's own folder is linked into the canonical
#      folder (~/.agents/skills/steer), so running it from a checkout is enough.
#   2. companion skills (tdd, grilling, ...): looked up next to steer, then in
#      STEER_SKILLS_PATH, then in a clone of STEER_SKILLS_GIT, and linked into
#      the canonical folder the same way. Anything already installed is kept.
#   3. every present canonical skill is linked into each harness root.
#
# Idempotent: safe to re-run after editing any skill.
#
# Environment:
#   AGENTS_SKILLS_DIR   canonical folder (default ~/.agents/skills)
#   STEER_SKILLS_PATH   extra folders to search for companion skills, colon-
#                       separated. Each may hold <name>/ or skills/<name>/.
#   STEER_SKILLS_GIT    git URL of a repo holding companion skills; cloned (or
#                       fast-forwarded) into ~/.agents/.sources/steer-skills
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

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_PARENT="$(dirname "$SELF_DIR")"
CANON="${AGENTS_SKILLS_DIR:-$HOME/.agents/skills}"
ROOTS=("$HOME/.claude/skills" "$HOME/.pi/agent/skills")
MARKER=.steer-install-copy

# steer calls these in every run.
REQUIRED=(tdd code-review grilling domain-modeling)
# steer calls these only when the work calls for them (see SKILL.md, Design and
# Handoff). Missing ones are reported, never fatal.
OPTIONAL=(codebase-design prototype to-spec handoff)
# Installed when found, never reported missing (claude-handoff is an alternative
# to handoff that also launches the continuation).
ALSO=(implement claude-handoff)

if [ ! -f "$SELF_DIR/SKILL.md" ]; then
  echo "FAIL  $SELF_DIR has no SKILL.md — run this script from inside the steer folder"
  exit 1
fi

win_path() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w "$1"
  else
    printf '%s\n' "$1" | sed 's|/|\\|g'
  fi
}

# Physical path of a directory or a link to one; empty if it does not resolve.
real() { (cd "$1" 2>/dev/null && pwd -P); }

same_target() {
  [ -e "$1" ] || return 1
  local a b
  a="$(real "$1")"
  b="$(real "$2")"
  [ -n "$a" ] && [ "$a" = "$b" ]
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
  local probe="$CANON/.steer-link-probe"
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
  mkdir -p "$(dirname "$target")" 2>/dev/null

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

# A directory this script previously copied, or a content-equal duplicate of
# the source skill (line endings ignored). Either is ours to replace.
replaceable() {
  local target="$1" source="$2"
  [ -f "$target/$MARKER" ] && return 0
  diff -r --strip-trailing-cr --exclude="$MARKER" "$source" "$target" >/dev/null 2>&1
}

copies_made=0
failures=0

# link_into <source> <target> — make <target> a link to <source>, replacing only
# what is ours to replace. Used for both canonical and harness-root links.
link_into() {
  local source="$1" target="$2"

  if [ ! -d "$source" ]; then
    echo "SKIP  $target — no source $source"
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
    if same_target "$target" "$source"; then
      echo "OK    $target — is the canonical folder"
      return
    fi
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
    failures=1
  fi
}

# ── companion skill sources ─────────────────────────────────────────────────

SEARCH=("$SRC_PARENT")
if [ -n "${STEER_SKILLS_PATH:-}" ]; then
  IFS=: read -r -a _extra <<<"$STEER_SKILLS_PATH"
  for _d in "${_extra[@]}"; do
    [ -n "$_d" ] && SEARCH+=("$_d")
  done
fi

if [ -n "${STEER_SKILLS_GIT:-}" ]; then
  GIT_DIR_LOCAL="$HOME/.agents/.sources/steer-skills"
  if ! command -v git >/dev/null 2>&1; then
    echo "WARN  STEER_SKILLS_GIT is set but git is not installed — skipped"
  elif [ -d "$GIT_DIR_LOCAL/.git" ]; then
    if git -C "$GIT_DIR_LOCAL" pull --ff-only -q 2>/dev/null; then
      echo "OK    updated $GIT_DIR_LOCAL"
    else
      echo "WARN  could not update $GIT_DIR_LOCAL — using what is there"
    fi
    SEARCH+=("$GIT_DIR_LOCAL")
  else
    mkdir -p "$(dirname "$GIT_DIR_LOCAL")"
    if git clone --depth 1 -q "$STEER_SKILLS_GIT" "$GIT_DIR_LOCAL" 2>/dev/null; then
      echo "OK    cloned $STEER_SKILLS_GIT into $GIT_DIR_LOCAL"
      SEARCH+=("$GIT_DIR_LOCAL")
    else
      echo "WARN  could not clone $STEER_SKILLS_GIT — companion skills not fetched"
    fi
  fi
fi

# find_source <name> — first folder under SEARCH holding <name>/SKILL.md.
find_source() {
  local name="$1" d cand
  for d in "${SEARCH[@]}"; do
    for cand in "$d/$name" "$d/skills/$name"; do
      if [ -f "$cand/SKILL.md" ]; then
        printf '%s\n' "$cand"
        return 0
      fi
    done
  done
  return 1
}

# present_in_root <name> — is it installed in any harness root, outside canonical?
present_in_root() {
  local name="$1" root
  for root in "${ROOTS[@]}"; do
    [ -e "$root/$name/SKILL.md" ] && {
      printf '%s\n' "$root"
      return 0
    }
  done
  return 1
}

# ensure_canonical <name> <source> — put <source> at $CANON/<name> unless a
# working copy is already there. Never repoints a working canonical link.
ensure_canonical() {
  local name="$1" source="$2"
  local target="$CANON/$name"

  if [ -L "$target" ] && [ ! -e "$target" ]; then
    echo "NOTE  $target is a dangling link — replacing"
    remove_link "$target" || {
      echo "WARN  $target could not be removed — left alone"
      return 1
    }
  elif [ -e "$target" ]; then
    if same_target "$target" "$source"; then
      echo "OK    $target — already links to $source"
      return 0
    fi
    if [ -d "$target" ] && [ ! -L "$target" ] && replaceable "$target" "$source"; then
      rm -rf "$target"
    else
      echo "NOTE  $target — already installed and differs from $source; kept, not replaced"
      return 0
    fi
  fi

  if make_link "$target" "$source"; then
    echo "LINK  $target -> $source ($LINK_HOW)"
    [ "$LINK_HOW" = copy ] && copies_made=1
    return 0
  fi
  echo "FAIL  $target — could not link or copy"
  failures=1
  return 1
}

# ── 1. canonical folder ─────────────────────────────────────────────────────

mkdir -p "$CANON"
echo "== canonical: $CANON"

INSTALL=() # names present in canonical, to be linked into every root
MISSING_REQUIRED=()
MISSING_OPTIONAL=()
ELSEWHERE=() # present in a harness root only; usable, but not managed here

ensure_canonical steer "$SELF_DIR" && INSTALL+=(steer)

resolve_skill() { # <name> <required|optional|also>
  local name="$1" kind="$2" src root
  if src="$(find_source "$name")"; then
    ensure_canonical "$name" "$src" && INSTALL+=("$name")
  elif [ -e "$CANON/$name/SKILL.md" ]; then
    echo "OK    $CANON/$name — already installed"
    INSTALL+=("$name")
  elif root="$(present_in_root "$name")"; then
    echo "HAVE  $name in $root (not in canonical — left where it is)"
    ELSEWHERE+=("$name")
  else
    case "$kind" in
      required) MISSING_REQUIRED+=("$name") ;;
      optional) MISSING_OPTIONAL+=("$name") ;;
    esac
  fi
}

for name in "${REQUIRED[@]}"; do resolve_skill "$name" required; done
for name in "${OPTIONAL[@]}"; do resolve_skill "$name" optional; done
for name in "${ALSO[@]}"; do resolve_skill "$name" also; done

# ── 2. harness roots ────────────────────────────────────────────────────────

for root in "${ROOTS[@]}"; do
  echo "== root: $root"
  if [ ! -d "$root" ]; then
    echo "SKIP  $root — harness root not present"
    continue
  fi
  for name in ${INSTALL[@]+"${INSTALL[@]}"}; do
    link_into "$CANON/$name" "$root/$name"
  done
done

# ── 3. report ───────────────────────────────────────────────────────────────

echo
if [ "${#MISSING_REQUIRED[@]}" -gt 0 ]; then
  echo "WARN  steer calls these skills on every run and none was found:"
  printf '        %s\n' "${MISSING_REQUIRED[@]}"
fi
if [ "${#MISSING_OPTIONAL[@]}" -gt 0 ]; then
  echo "NOTE  steer calls these only for some work (Design, Handoff); not found:"
  printf '        %s\n' "${MISSING_OPTIONAL[@]}"
fi
if [ "${#MISSING_REQUIRED[@]}" -gt 0 ] || [ "${#MISSING_OPTIONAL[@]}" -gt 0 ]; then
  echo "      Put each missing skill's folder next to steer ($SRC_PARENT/<name>/),"
  echo "      or set STEER_SKILLS_PATH=/dir/with/skills, or STEER_SKILLS_GIT=<repo url>,"
  echo "      then re-run. Until then steer approximates the craft and logs a carried"
  echo "      doubt, as its Agent protocol says."
else
  echo "OK    steer and every companion skill are installed."
fi

if [ "$copies_made" = 1 ]; then
  echo
  echo "NOTE  At least one root got a COPY, not a link: no link mechanism was"
  echo "      available. Re-run this script after every edit to a canonical"
  echo "      skill, or enable Windows Developer Mode so 'mklink' succeeds."
fi

exit "$failures"
