#!/bin/sh

# Path to binaries on Kobo
CURL_BIN="/mnt/onboard/.niluje/usbnet/bin/curl"
JQ_BIN="/mnt/onboard/.niluje/usbnet/bin/jq"
ENV_FILE="/mnt/onboard/.adds/pkm/.env"

# Source environment file
if [ -f "$ENV_FILE" ]; then
    . "$ENV_FILE"
else
    echo "Error: Environment file not found at $ENV_FILE" >&2
    exit 1
fi

# Check if URL is provided
if [ -z "$1" ]; then
    echo "Error: No course URL provided" >&2
    exit 1
fi

# Check if jq exists
if [ ! -f "$JQ_BIN" ]; then
    echo "Error: jq not found at $JQ_BIN" >&2
    exit 1
fi

# Create JSON request for syllabus
json_data=$($JQ_BIN -n --arg url "$1" \
    '{"url": $url, "page": "syllabus", "format": "epub"}')

# Fetch syllabus
response=$($CURL_BIN -s -X POST \
    -H "Content-Type: application/json" \
    -d "$json_data" \
    "$SERVER_URL/fetch-content")

# Output the response for the QT plugin to parse
echo "$response" 