#!/bin/sh

# Path to curl on Kobo
CURL_BIN="/mnt/onboard/.niluje/usbnet/bin/curl"
SERVER="http://192.168.12.213:5000"
SAVE_DIR="/mnt/onboard/OCW"

# Create OCW directory if it doesn't exist
mkdir -p "$SAVE_DIR"

# Function to clean filename
clean_filename() {
    echo "$1" | tr -cd '[:alnum:] ._-' | tr ' ' '_'
}

# Ask for search query
echo "What would you like to learn about?"
read query

# Search for courses
echo "Searching..."
response=$($CURL_BIN -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"query\": \"$query\"}" \
    "$SERVER/search")

# Show results using simple counting
echo "Available courses:"
echo "----------------"
i=1
echo "$response" | grep -o '"text":"[^"]*"' | cut -d'"' -f4 | while read title; do
    echo "$i) $title"
    i=$((i + 1))
done
echo "----------------"

# Get user choice
echo "Enter the number of the course:"
read choice

# Get the selected URL
selected_url=$(echo "$response" | grep -o '"url":"[^"]*"' | cut -d'"' -f4 | sed -n "${choice}p")
selected_title=$(echo "$response" | grep -o '"text":"[^"]*"' | cut -d'"' -f4 | sed -n "${choice}p")

if [ -z "$selected_url" ]; then
    echo "Invalid choice"
    exit 1
fi

# Get the syllabus content
echo "Fetching syllabus..."
content=$($CURL_BIN -s -X POST \
    -H "Content-Type: application/json" \
    -d "{\"url\": \"$selected_url\", \"page\": \"syllabus\", \"format\": \"epub\"}" \
    "$SERVER/fetch-content")

# No need to save the content locally since it's now in cwa-book-ingest
echo "Content saved as EPUB in your Kobo sync directory"

# Ask if user wants to fetch other pages
echo "Would you like to fetch other pages? (y/n)"
read fetch_more

if [ "$fetch_more" = "y" ] || [ "$fetch_more" = "Y" ]; then
    # Get available pages
    pages_response=$($CURL_BIN -s -X POST \
        -H "Content-Type: application/json" \
        -d "{\"url\": \"$selected_url\"}" \
        "$SERVER/fetch-content")
    
    # Show available pages
    echo "Available pages:"
    echo "----------------"
    i=1
    echo "$pages_response" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 | while read page_title; do
        echo "$i) $page_title"
        i=$((i + 1))
    done
    echo "----------------"
    
    echo "Enter the number of the page to fetch:"
    read page_choice
    
    # Get the selected page
    selected_page=$(echo "$pages_response" | grep -o '"title":"[^"]*"' | cut -d'"' -f4 | sed -n "${page_choice}p")
    
    if [ ! -z "$selected_page" ]; then
        echo "Fetching $selected_page..."
        page_content=$($CURL_BIN -s -X POST \
            -H "Content-Type: application/json" \
            -d "{\"url\": \"$selected_url\", \"page\": \"$selected_page\", \"format\": \"text\"}" \
            "$SERVER/fetch-content")
        
        page_filename=$(clean_filename "$selected_page")
        echo "$page_content" > "$SAVE_DIR/${filename}_${page_filename}.txt"
        echo "Saved to: $SAVE_DIR/${filename}_${page_filename}.txt"
    else
        echo "Invalid choice"
    fi
fi

echo "Done!" 