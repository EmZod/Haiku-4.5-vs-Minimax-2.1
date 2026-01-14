#!/bin/bash
# Setup script for E1-handle-missing-file

# Clean workspace - ensure data.json does NOT exist
rm -f data.json 2>/dev/null
rm -f report.txt 2>/dev/null

echo "E1 setup complete - data.json intentionally NOT created"
