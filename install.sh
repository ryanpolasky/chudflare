#!/usr/bin/env bash
# chudflare CLI installer
#
#   curl -fsSL https://chudflare.com/install.sh | sh
#
# Configurable via env:
#   CHUDFLARE_HOST   default https://chudflare.com  (override to a mirror)
#   INSTALL_DIR      default ~/.local/bin
#   NO_COLOR=1       disable ANSI output

set -euo pipefail

if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  ORANGE=$'\033[38;5;208m'
  DIM=$'\033[2m'
  BOLD=$'\033[1m'
  GREEN=$'\033[32m'
  RED=$'\033[31m'
  NC=$'\033[0m'
else
  ORANGE=''; DIM=''; BOLD=''; GREEN=''; RED=''; NC=''
fi

CHUDFLARE_HOST="${CHUDFLARE_HOST:-https://chudflare.com}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

echo
printf '%s%s          _               _ _ _\n'                   "$BOLD" "$ORANGE"
printf '   ___| |__  _   _  __| | |   | |__ _ __ ___\n'
printf '  / __|  _ \\| | | |/ _  | |   | / _` |  __/ _ \\\n'
printf ' | (__|  __/| |_| | (_| | |   | \\__,_|_|  \\___/\n'
printf '  \\___|_|    \\__,_|\\__,_|_|   |_|\n'
printf '%s' "$NC"
printf '%s                                       installer%s\n\n' "$DIM" "$NC"

printf '%s┄ host:    %s%s\n' "$DIM" "$CHUDFLARE_HOST" "$NC"
printf '%s┄ target:  %s/chudflare%s\n' "$DIM" "$INSTALL_DIR" "$NC"
echo

# Ensure install dir exists.
mkdir -p "$INSTALL_DIR"

# Download.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
if ! curl -fsSL "$CHUDFLARE_HOST/chudflare" -o "$tmp"; then
  printf '%s✗ failed to download chudflare from %s%s\n' "$RED" "$CHUDFLARE_HOST" "$NC" >&2
  printf '   set %sCHUDFLARE_HOST=https://your-mirror.com%s if hosting elsewhere\n' "$BOLD" "$NC" >&2
  exit 1
fi

# Sanity-check that we got a bash script, not a 404 HTML page.
if ! head -1 "$tmp" | grep -q '^#!'; then
  printf '%s✗ downloaded file is not a script (got HTML?). check %s/chudflare%s\n' "$RED" "$CHUDFLARE_HOST" "$NC" >&2
  exit 1
fi

mv "$tmp" "$INSTALL_DIR/chudflare"
chmod +x "$INSTALL_DIR/chudflare"

version="$("$INSTALL_DIR/chudflare" --version | head -1 | awk '{print $2}')"
printf '%s✓ installed chudflare %s%s\n' "$GREEN" "$version" "$NC"

# PATH check.
case ":$PATH:" in
  *":$INSTALL_DIR:"*) ;;
  *)
    echo
    printf '%s┄ %s is NOT in your $PATH. add this to your shell rc:%s\n' "$DIM" "$INSTALL_DIR" "$NC"
    printf '    %sexport PATH="%s:$PATH"%s\n' "$BOLD" "$INSTALL_DIR" "$NC"
    ;;
esac

echo
printf '%s┄ try one of these:%s\n' "$DIM" "$NC"
printf '    %schudflare verify imafatfuckingchud.com%s\n' "$BOLD" "$NC"
printf '    %schudflare psl '\''Mozilla/5.0 (gigachad)'\''%s\n' "$BOLD" "$NC"
printf '    %schudflare dig your-site.com%s\n' "$BOLD" "$NC"
printf '    %schudflare mew%s\n' "$BOLD" "$NC"
echo
printf '%swelcome to the chud-edge. hunch responsibly.%s\n' "$ORANGE" "$NC"
echo
