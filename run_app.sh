#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$DIR"

echo "======================================================="
echo " Launching BioCard APDU Inspector GUI App"
echo "======================================================="

# Recompile if binary is older than sources
if [ ! -d "BioCard.app" ]; then
    echo "Building BioCard.app..."
    swift build -c release --product BioCardApp
    mkdir -p BioCard.app/Contents/MacOS BioCard.app/Contents/Resources
    cp .build/release/BioCardApp BioCard.app/Contents/MacOS/BioCardApp
    codesign --force --deep --sign - BioCard.app
fi

echo "Opening BioCard.app..."
open "$DIR/BioCard.app"
echo "App launched successfully!"
