#!/bin/sh
bounds=$(osascript -l JavaScript -e '
ObjC.import("AppKit");
const fs = $.NSScreen.screens.js.map(s => s.frame);
const f = fs.reduce((a, b) => a.size.width * a.size.height >= b.size.width * b.size.height ? a : b);
const w = Math.min(1920, f.size.width), h = Math.min(1080, f.size.height);
const x = f.origin.x + (f.size.width - w) / 2;
const y = fs[0].size.height - f.origin.y - f.size.height + (f.size.height - h) / 2;
[x, y, x + w, y + h].map(Math.round).join(", ")')
( until curl -s -o /dev/null http://127.0.0.1:8000; do sleep 0.5; done
  osascript -e 'tell application "Safari"' \
    -e 'make new document with properties {URL:"http://127.0.0.1:8000"}' \
    -e 'activate' \
    -e "set bounds of front window to {$bounds}" \
    -e 'end tell' ) &
exec uv run "$(dirname "$0")/app.py"
