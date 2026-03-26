#!/bin/sh
# finder-test.sh for Assignment 4

set -e

CONFIG_DIR="/etc/finder-app/conf"
OUTPUT="/tmp/assignment4-result.txt"

finder.sh "$CONFIG_DIR" > "$OUTPUT"

echo "Result written to $OUTPUT"
