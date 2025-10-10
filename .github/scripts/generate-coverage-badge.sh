#!/bin/bash

# Script to generate a coverage badge JSON file for shields.io

COVERAGE_FILE="$1"
OUTPUT_FILE="${2:-.github/coverage-badge.json}"

if [ ! -f "$COVERAGE_FILE" ]; then
    echo "Coverage file not found: $COVERAGE_FILE"
    exit 1
fi

# Extract overall coverage percentage from llvm-cov report
# Format: "TOTAL  123  100  81.44%"
COVERAGE=$(grep "^TOTAL" "$COVERAGE_FILE" | grep -oE '[0-9]+\.[0-9]+%' | head -n 1 | sed 's/%//')

if [ -z "$COVERAGE" ]; then
    echo "Could not extract coverage percentage from $COVERAGE_FILE"
    exit 1
fi

echo "Extracted coverage: $COVERAGE%"

# Determine badge color based on coverage threshold
if (( $(echo "$COVERAGE >= 80" | bc -l) )); then
    COLOR="brightgreen"
elif (( $(echo "$COVERAGE >= 60" | bc -l) )); then
    COLOR="yellow"
elif (( $(echo "$COVERAGE >= 40" | bc -l) )); then
    COLOR="orange"
else
    COLOR="red"
fi

# Create directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Generate badge JSON for shields.io endpoint
cat > "$OUTPUT_FILE" << EOF
{
  "schemaVersion": 1,
  "label": "coverage",
  "message": "${COVERAGE}%",
  "color": "${COLOR}"
}
EOF

echo "Generated badge JSON at $OUTPUT_FILE"
echo "Badge will display: coverage ${COVERAGE}% ($COLOR)"
