#!/bin/bash
# Setup script for C1-debug-the-bug

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copy the buggy file to workspace
cp "$SCRIPT_DIR/buggy.py" ./buggy.py

echo "C1 setup complete - buggy.py copied to workspace"
