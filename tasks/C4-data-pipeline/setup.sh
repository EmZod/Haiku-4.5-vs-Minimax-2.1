#!/bin/bash
# Setup script for C4-data-pipeline

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Copy the input data
cp "$SCRIPT_DIR/orders.json" ./orders.json

# Ensure output doesn't exist
rm -f summary.csv

echo "C4 setup complete - orders.json copied"
