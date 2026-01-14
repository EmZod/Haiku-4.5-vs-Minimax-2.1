#!/bin/bash
# Setup script for A2-count-lines

# Clean workspace
rm -f output.txt 2>/dev/null

# Create input file with 7 lines
cat > input.txt << 'EOF'
The quick brown fox
jumps over
the lazy dog
Lorem ipsum dolor sit amet
consectetur adipiscing elit
sed do eiusmod tempor
incididunt ut labore
EOF

echo "A2 setup complete - input.txt created with 7 lines"
