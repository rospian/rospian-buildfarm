#!/bin/bash

# Script to generate Trixie rosdep rules from Bookworm pickle cache

OUTPUT_FILE="/tmp/42-debian-trixie.yaml"
CACHE_DIR="$HOME/.ros/rosdep/sources.cache"

echo "Generating Trixie rosdep rules from Bookworm definitions..."

python3 << 'EOF' > "$OUTPUT_FILE"
import pickle
import sys
from pathlib import Path

cache_dir = Path.home() / '.ros/rosdep/sources.cache'
trixie_rules = {}

# Read all cached pickle files
for file in sorted(cache_dir.glob('*.pickle')):
    try:
        with open(file, 'rb') as f:
            data = pickle.load(f)
            if not data:
                continue
            
            for key, value in data.items():
                if isinstance(value, dict) and 'debian' in value:
                    if isinstance(value['debian'], dict) and 'bookworm' in value['debian']:
                        # Create entry for this package
                        if key not in trixie_rules:
                            trixie_rules[key] = {'debian': {}}
                        
                        # Copy bookworm definition to trixie
                        trixie_rules[key]['debian']['trixie'] = value['debian']['bookworm']
    except Exception as e:
        print(f"# Error processing {file}: {e}", file=sys.stderr)
        continue

# Write out the YAML file
print("# Auto-generated Trixie rosdep rules based on Bookworm definitions")
print(f"# Generated from cache at: {cache_dir}")
print("# Add this file to: /etc/ros/rosdep/sources.list.d/")
print()

def write_yaml_value(value, indent=0):
    """Helper to write YAML values with proper formatting"""
    spaces = '  ' * indent
    if isinstance(value, dict):
        for k, v in value.items():
            print(f"{spaces}{k}:")
            write_yaml_value(v, indent + 1)
    elif isinstance(value, list):
        for item in value:
            if isinstance(item, dict):
                print(f"{spaces}-")
                write_yaml_value(item, indent + 1)
            else:
                print(f"{spaces}- {item}")
    else:
        return value

for key in sorted(trixie_rules.keys()):
    print(f"{key}:")
    print(f"  debian:")
    print(f"    trixie:")
    
    bookworm_def = trixie_rules[key]['debian']['trixie']
    write_yaml_value(bookworm_def, indent=3)
    print()

EOF

if [ $? -eq 0 ]; then
    echo "✓ Generated rules file: $OUTPUT_FILE"
    echo ""
    echo "Number of packages mapped:"
    grep -c "^[a-zA-Z_]" "$OUTPUT_FILE" || echo "0"
    echo ""
    echo "To install:"
    echo "  sudo cp $OUTPUT_FILE /etc/ros/rosdep/sources.list.d/"
    echo "  rosdep update"
    echo ""
    echo "Preview (first 50 lines):"
    head -50 "$OUTPUT_FILE"
else
    echo "✗ Failed to generate rules file"
    exit 1
fi