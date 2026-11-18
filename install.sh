#!/bin/bash
# Install the uncordex command for the current macOS user.
#   From a clone:  ./install.sh
#   One line:      curl -fsSL https://raw.githubusercontent.com/magrathean-uk/uncordex/main/install.sh | bash
# Installs files only. Run 'uncordex setup' afterwards to choose your speaker.
set -euo pipefail

REPO_TARBALL="https://github.com/magrathean-uk/uncordex/archive/refs/heads/main.tar.gz"
APP_DIR="${UNCORDEX_APP_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/uncordex}"
BIN_DIR="${UNCORDEX_BIN_DIR:-$HOME/.local/bin}"
LABEL="uk.magrathean.uncordex.watch-power"
LAUNCHCTL="${UNCORDEX_LAUNCHCTL:-/bin/launchctl}"
INSTALL_DEPENDENCIES=1

fail() { /usr/bin/printf 'uncordex install: %s\n' "$1" >&2; shift; while [ "$#" -gt 0 ]; do /usr/bin/printf '  %s\n' "$1" >&2; shift; done; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-install-dependencies) INSTALL_DEPENDENCIES=0; shift ;;
    -h|--help)
      /usr/bin/printf '%s\n' "Usage: ./install.sh [--no-install-dependencies]" \
        "Installs the uncordex command to $BIN_DIR and installs blueutil with Homebrew if it is missing."
      exit 0 ;;
    *) fail "unknown option: $1" "Usage: ./install.sh [--no-install-dependencies]" ;;
  esac
done

[ "$(/usr/bin/uname -s)" = Darwin ] || fail "Uncordex runs on macOS only."

WORK=""
cleanup() { [ -z "$WORK" ] || /bin/rm -rf "$WORK"; }
trap cleanup EXIT HUP INT TERM

SOURCE_DIR=""
if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "$(/usr/bin/dirname "${BASH_SOURCE[0]}")/uncordex" ]; then
  SOURCE_DIR="$(cd "$(/usr/bin/dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  WORK="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/uncordex-install.XXXXXX")"
  /usr/bin/printf '%s\n' "Downloading Uncordex..."
  /usr/bin/curl -fsSL "$REPO_TARBALL" | /usr/bin/tar -xz -C "$WORK" --strip-components 1 ||
    fail "download failed." "Check your internet connection and try again."
  SOURCE_DIR="$WORK"
fi
for file in uncordex watch-power lib/source.sh VERSION helper/uncordex-helper.c helper/Info.plist; do
  [ -f "$SOURCE_DIR/$file" ] || fail "the download is incomplete ($file is missing)." "Try again in a minute."
done
/bin/bash -n "$SOURCE_DIR/uncordex" "$SOURCE_DIR/watch-power" "$SOURCE_DIR/lib/source.sh" || fail "the downloaded files are damaged."

# Replace each file atomically so a running watcher keeps reading its old copy.
place() {
  local mode from to tmp
  mode="$1"; from="$2"; to="$3"
  tmp="$(/usr/bin/mktemp "$to.XXXXXX")"
  /bin/cp "$from" "$tmp"
  /bin/chmod "$mode" "$tmp"
  /bin/mv -f "$tmp" "$to"
}
/bin/mkdir -p "$APP_DIR/lib" "$BIN_DIR"
place 755 "$SOURCE_DIR/uncordex" "$APP_DIR/uncordex"
place 755 "$SOURCE_DIR/watch-power" "$APP_DIR/watch-power"
place 644 "$SOURCE_DIR/lib/source.sh" "$APP_DIR/lib/source.sh"
place 644 "$SOURCE_DIR/VERSION" "$APP_DIR/VERSION"
/bin/ln -sfn "$APP_DIR/uncordex" "$BIN_DIR/uncordex"

# Uncordex.app is a tiny helper that holds Uncordex's Bluetooth permission, so
# macOS asks about "Uncordex" instead of stopping blueutil inside a terminal.
build_helper() {
  local app stage hash_now hash_old clang
  app="$APP_DIR/Uncordex.app"
  hash_now="$(/bin/cat "$SOURCE_DIR/helper/uncordex-helper.c" "$SOURCE_DIR/helper/Info.plist" | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}')"
  hash_old="$(/bin/cat "$app/Contents/Resources/source.sha256" 2>/dev/null || true)"
  # Rebuilding changes the signature and macOS would ask again, so only rebuild on change.
  if [ "$hash_now" = "$hash_old" ] && [ -x "$app/Contents/MacOS/uncordex-helper" ]; then return 0; fi
  clang="$(/usr/bin/xcrun --find clang 2>/dev/null || true)"
  if [ -z "$clang" ]; then
    /usr/bin/printf '%s\n' "Could not build Uncordex's Bluetooth helper: Apple's command line tools are missing." \
      "Install them with: xcode-select --install   then run this installer again." >&2
    return 1
  fi
  stage="$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/uncordex-helper.XXXXXX")/Uncordex.app"
  /bin/mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources"
  /usr/bin/xcrun clang -O2 -mmacosx-version-min=13.0 -arch arm64 -arch x86_64 -o "$stage/Contents/MacOS/uncordex-helper" "$SOURCE_DIR/helper/uncordex-helper.c" 2>/dev/null ||
    /usr/bin/xcrun clang -O2 -mmacosx-version-min=13.0 -o "$stage/Contents/MacOS/uncordex-helper" "$SOURCE_DIR/helper/uncordex-helper.c" || return 1
  /bin/cp "$SOURCE_DIR/helper/Info.plist" "$stage/Contents/Info.plist"
  /usr/bin/printf '%s\n' "$hash_now" >"$stage/Contents/Resources/source.sha256"
  /usr/bin/codesign --force --sign - "$stage" >/dev/null 2>&1 || return 1
  /bin/rm -rf "$app"
  /bin/mv "$stage" "$app"
  /bin/rmdir "$(/usr/bin/dirname "$stage")" 2>/dev/null || true
}
if [ "${UNCORDEX_BUILD_HELPER:-1}" = 1 ]; then
  build_helper || /usr/bin/printf '%s\n' "Warning: without the helper, macOS may refuse Bluetooth access from a terminal." >&2
fi

if ! [ -x /opt/homebrew/bin/blueutil ] && ! [ -x /usr/local/bin/blueutil ] && ! command -v blueutil >/dev/null 2>&1; then
  BREW="${UNCORDEX_BREW:-$(command -v brew 2>/dev/null || true)}"
  if [ -z "$BREW" ]; then
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [ -x "$candidate" ]; then BREW="$candidate"; break; fi
    done
  fi
  if [ "$INSTALL_DEPENDENCIES" -eq 1 ] && [ -n "$BREW" ]; then
    /usr/bin/printf '%s\n' "Installing blueutil with Homebrew..."
    "$BREW" install blueutil || /usr/bin/printf '%s\n' "Could not install blueutil. Install it later with: brew install blueutil" >&2
  else
    /usr/bin/printf '%s\n' "Uncordex needs blueutil. Install Homebrew (https://brew.sh), then run: brew install blueutil" >&2
  fi
fi

# An existing service picks up the new watcher straight away.
if "$LAUNCHCTL" print "gui/$(/usr/bin/id -u)/$LABEL" >/dev/null 2>&1; then
  "$LAUNCHCTL" kickstart -k "gui/$(/usr/bin/id -u)/$LABEL" >/dev/null 2>&1 || true
fi

/usr/bin/printf '\n%s\n' "Installed uncordex $(/bin/cat "$APP_DIR/VERSION") to $BIN_DIR/uncordex"
case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) /usr/bin/printf '%s\n' "" "$BIN_DIR is not on your PATH yet. Add it with:" \
       "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> ~/.zshrc && source ~/.zshrc" ;;
esac
/usr/bin/printf '%s\n' "" "Next:  uncordex setup"
