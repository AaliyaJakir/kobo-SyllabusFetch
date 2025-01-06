#!/bin/sh

# Path to binaries on Kobo
CURL_BIN="/mnt/onboard/.niluje/usbnet/bin/curl"
JQ_BIN="/mnt/onboard/.niluje/usbnet/bin/jq"
CONFIG_FILE="/mnt/onboard/.adds/pkm/config.txt"

# Source environment file
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    echo "Error: Config file not found at $CONFIG_FILE" >&2
    exit 1
fi

# Check if notebook path is provided
if [ -z "$1" ]; then
    echo "Error: No notebook path provided" >&2
    exit 1
fi

# Check if file exists
if [ ! -f "$1" ]; then
    echo "Error: File $1 does not exist" >&2
    exit 1
fi

# Check if jq exists
if [ ! -f "$JQ_BIN" ]; then
    echo "Error: jq not found at $JQ_BIN" >&2
    exit 1
fi

# Read the notebook content and create properly escaped JSON
query=$(cat "$1" | $JQ_BIN -R -s '.')

# Create JSON request using jq
json_data=$($JQ_BIN -n --arg q "$query" '{"query": ($q | fromjson)}')

# Search for courses
response=$($CURL_BIN -s -X POST \
    -H "Content-Type: application/json" \
    -d "$json_data" \
    "$SERVER_URL/search")

# Output the response for the QT plugin to parse
echo "$response" 