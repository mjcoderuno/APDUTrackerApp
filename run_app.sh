#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "======================================================="
echo " Launching APDUTracker APDU Inspector GUI App"
echo "======================================================="

# Recompile if binary is older than sources
if [ ! -d "APDUTracker.app" ]; then
    echo "Building APDUTracker.app..."
    swift build -c release --product APDUTrackerApp
    mkdir -p APDUTracker.app/Contents/MacOS APDUTracker.app/Contents/Resources
    cp .build/release/APDUTrackerApp APDUTracker.app/Contents/MacOS/APDUTrackerApp
    codesign --force --deep --sign - APDUTracker.app
fi

echo "Opening APDUTracker.app..."
open "$DIR/APDUTracker.app"
echo "App launched successfully!"
