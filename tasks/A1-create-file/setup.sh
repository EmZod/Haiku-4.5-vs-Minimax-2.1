#!/bin/bash
# Setup script for A1-create-file
# Called before agent runs, in the agent's workspace directory

# Ensure workspace is clean
rm -f hello.txt 2>/dev/null

echo "A1 setup complete - workspace is clean"
