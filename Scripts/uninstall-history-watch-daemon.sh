#!/bin/sh
# Stops and removes the LaunchAgent installed by install-history-watch-daemon.sh.
# Does not touch any already-written watch log/state files or Full Disk Access.
set -eu

LABEL="com.naitikgupta.wingman.history-watch"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
UID_NUM="$(id -u)"

launchctl bootout "gui/$UID_NUM/$LABEL" >/dev/null 2>&1 || true

if [ -f "$PLIST_PATH" ]; then
  rm "$PLIST_PATH"
  echo "Removed $PLIST_PATH"
else
  echo "No LaunchAgent plist found at $PLIST_PATH"
fi

echo "Stopped and uninstalled $LABEL."
echo "Watch history log and checkpoint under ~/Library/Application Support/Wingman were left in place."
