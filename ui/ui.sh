#!/bin/sh
url=http://127.0.0.1:8000
bounds=$(osascript -l JavaScript -e '
ObjC.import("AppKit");
const fs = $.NSScreen.screens.js.map(s => s.frame);
const f = fs.reduce((a, b) => a.size.width * a.size.height >= b.size.width * b.size.height ? a : b);
const w = Math.min(1920, f.size.width), h = Math.min(1080, f.size.height);
const x = f.origin.x + (f.size.width - w) / 2;
const y = fs[0].size.height - f.origin.y - f.size.height + (f.size.height - h) / 2;
[x, y, x + w, y + h].map(Math.round).join(", ")')
# safari and chrome can be scripted to place the window; any other default browser just gets the url
browser=$(osascript -l JavaScript -e 'ObjC.import("AppKit");
$.NSWorkspace.sharedWorkspace.URLForApplicationToOpenURL($.NSURL.URLWithString("http://localhost")).lastPathComponent.js')
( until curl -s -o /dev/null $url; do sleep 0.5; done
  case $browser in
    Safari.app)
      osascript -e 'tell application "Safari"' \
        -e "make new document with properties {URL:\"$url\"}" \
        -e 'activate' \
        -e "set bounds of front window to {$bounds}" \
        -e 'end tell' ;;
    "Google Chrome.app")
      osascript -e 'tell application "Google Chrome"' \
        -e 'make new window' \
        -e "set URL of active tab of front window to \"$url\"" \
        -e 'activate' \
        -e "set bounds of front window to {$bounds}" \
        -e 'end tell' ;;
    *)
      open $url ;;
  esac ) &
exec uv run "$(dirname "$0")/app.py"
