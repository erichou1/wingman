#!/bin/sh
# Builds wingman-history in release mode and installs it as a per-user
# LaunchAgent so it auto-starts on login/reboot and keeps watching
# ~/Library/Messages/chat.db for new messages without the user having to
# remember to run `wingman-history export` manually.
#
# This only starts the watcher process. It does NOT and cannot grant Full
# Disk Access — that's a high-trust macOS permission the user must grant by
# hand (see the printed instructions below), matching the privacy design in
# docs/MESSAGE_HISTORY_ARCHITECTURE.md.
set -eu

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LABEL="com.naitikgupta.wingman.history-watch"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/Library/Logs/Wingman"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$LABEL.plist"
UID_NUM="$(id -u)"

echo "Building wingman-history (release)..."
cd "$REPO_ROOT"
swift build -c release --product wingman-history

BIN_PATH="$(swift build -c release --show-bin-path)/wingman-history"
if [ ! -x "$BIN_PATH" ]; then
  echo "error: expected binary at $BIN_PATH but it was not found" >&2
  exit 1
fi

mkdir -p "$LAUNCH_AGENTS_DIR" "$LOG_DIR"

sed \
  -e "s#__WINGMAN_HISTORY_BINARY__#$BIN_PATH#g" \
  -e "s#__WINGMAN_LOG_DIR__#$LOG_DIR#g" \
  "$REPO_ROOT/Scripts/$LABEL.plist.template" > "$PLIST_PATH"

# Re-installing: unload any previous instance of this agent first so
# bootstrap doesn't fail with "already bootstrapped".
launchctl bootout "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 || true

launchctl bootstrap "gui/$UID_NUM" "$PLIST_PATH"
launchctl enable "gui/$UID_NUM/$LABEL"
launchctl kickstart -k "gui/$UID_NUM/$LABEL"

cat <<EOF

Installed and started $LABEL.
  Binary:  $BIN_PATH
  Plist:   $PLIST_PATH
  Logs:    $LOG_DIR/history-watch.out.log
           $LOG_DIR/history-watch.err.log

One manual step required: grant Full Disk Access to the watcher binary.
  1. System Settings > Privacy & Security > Full Disk Access
  2. Click + and add:
       $BIN_PATH
  3. Enable the toggle next to it.

Until Full Disk Access is granted, the watcher will keep restarting
(KeepAlive) and logging a permission error to history-watch.err.log — that
is expected and harmless; it will pick up automatically once access is
granted.

To check status:   launchctl print gui/$UID_NUM/$LABEL
To uninstall:       Scripts/uninstall-history-watch-daemon.sh
EOF
