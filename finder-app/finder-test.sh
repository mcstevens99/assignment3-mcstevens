#!/bin/sh
# finder-test.sh for Assignment 4

set -e

OUTPUT="/tmp/assignment4-result.txt"

finder.sh > "$OUTPUT"

echo "Result written to $OUTPUT"
