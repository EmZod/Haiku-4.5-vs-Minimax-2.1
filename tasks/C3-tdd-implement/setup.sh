#!/bin/bash
# Setup script for C3-tdd-implement

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copy the test file to workspace
cp "$SCRIPT_DIR/test_solution.py" ./test_solution.py

# Ensure solution.py does NOT exist (agent must create it)
rm -f solution.py

echo "C3 setup complete - test_solution.py copied, solution.py must be created"
