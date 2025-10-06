#!/bin/sh
# Lists the titles of all visible windows for the given macOS application name.

if [ $# -ne 1 ]; then
  echo "Usage: $0 <application-name>" >&2
  exit 64
fi

APP_NAME=$1

osascript <<'APPLESCRIPT' "$APP_NAME"
on run argv
    set appName to item 1 of argv
    tell application "System Events"
        if not (exists application process appName) then
            error "Application '" & appName & "' is not running."
        end if
        set rawWindowNames to name of every window of application process appName
    end tell

    set filteredNames to {}
    repeat with winName in rawWindowNames
        if winName is not missing value and winName is not "" then
            copy (winName as text) to end of filteredNames
        end if
    end repeat

    if filteredNames is {} then
        return ""
    end if

    set AppleScript's text item delimiters to "\n"
    return filteredNames as text
end run
APPLESCRIPT
