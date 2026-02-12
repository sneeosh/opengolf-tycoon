#!/bin/bash
# Run GUT unit tests for OpenGolf Tycoon

# Find Godot executable
if [ -n "$GODOT" ]; then
    GODOT_BIN="$GODOT"
elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
elif [ -x "$HOME/Downloads/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_BIN="$HOME/Downloads/Godot.app/Contents/MacOS/Godot"
elif command -v godot &> /dev/null; then
    GODOT_BIN="godot"
else
    echo "Error: Godot not found. Set GODOT environment variable to your Godot executable path."
    exit 1
fi

echo "Using Godot: $GODOT_BIN"
"$GODOT_BIN" --headless --path . -s addons/gut/gut_cmdln.gd "$@"
