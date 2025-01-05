#!/bin/bash

# Create/clear the output file
OUTPUT_FILE="mit_courses.txt"
> "$OUTPUT_FILE"

# Get all course URLs from sitemap and remove sitemap.xml from the end
curl -s "https://ocw.mit.edu/sitemap.xml" | \
    grep -o 'https://ocw.mit.edu/courses/[^/]*/sitemap.xml' | \
    sed 's/\/sitemap.xml$//' | \
    sort -u > "$OUTPUT_FILE"

echo "✨ Saved $(wc -l < "$OUTPUT_FILE") course URLs to $OUTPUT_FILE"
