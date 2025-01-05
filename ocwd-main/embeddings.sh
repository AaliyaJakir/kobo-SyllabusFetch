#!/bin/sh

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Define paths
CURL_BIN="/mnt/onboard/.niluje/usbnet/bin/curl"
JQ_BIN="/mnt/onboard/.niluje/usbnet/bin/jq"
EMBEDDINGS_FILE="/mnt/onboard/query_embedding.json"

find_similar_courses() {
    local query="$1"
    
    echo -e "${YELLOW}Finding similar courses...${RESET}"
    
    # Create JSON request
    echo "{\"input\": \"$query\"}" > /tmp/query.json

    # Get embedding
    RESPONSE=$($CURL_BIN -s "https://roadmapproduction.openai.azure.com/openai/deployments/text-embedding-ada-002/embeddings?api-version=2023-05-15" \
        -H "Content-Type: application/json" \
        -H "api-key: d82038d046244e8eb6c88ffb39f613e9" \
        -d @/tmp/query.json)
    
    echo "$RESPONSE" | $JQ_BIN '.data[0].embedding' > "$EMBEDDINGS_FILE"
    
    # Simplified similarity search
    RESULTS=$($JQ_BIN -n --argjson query "$(cat $EMBEDDINGS_FILE)" --slurpfile courses "course_embeddings.json" '
        def dot_product(a; b): [a,b] | transpose | map(.[0] * .[1]) | add;
        def magnitude(v): (v | map(. * .) | add | sqrt);
        def cosine_sim(a; b): dot_product(a; b) / (magnitude(a) * magnitude(b));
        
        $courses[0] | map({
            title: .title,
            url: .url,
            score: cosine_sim(.embedding; $query)
        })
        | sort_by(-.score)
        | .[0:5]')

    # Display results
    echo -e "\n${GREEN}Top 5 recommended courses:${RESET}"
    echo "$RESULTS" | $JQ_BIN -r '.[] | select(.score > 0) | .url' > /tmp/urls.txt
    echo "$RESULTS" | $JQ_BIN -r '.[] | select(.score > 0) | "\(.title)\n  \(.url)\n"'
    
    # Get user selection
    echo -e "\n${YELLOW}Enter the number of the course you want to explore (1-5):${RESET}"
    read -r selection
    
    if [ "$selection" -ge 1 ] && [ "$selection" -le 5 ]; then
        selected_url=$(sed -n "${selection}p" /tmp/urls.txt)
        course_dir=$(echo "$selected_url" | grep -o 'courses/[^/]*' | cut -d'/' -f2)
        
        if [ -z "$course_dir" ]; then
            echo -e "${RED}Error: Could not extract course directory name${RESET}"
            exit 1
        fi
        
        echo -e "\n${YELLOW}Creating directory: $course_dir${RESET}"
        mkdir -p "$course_dir"
        
        echo -e "${YELLOW}Downloading course content...${RESET}"
        map_pages "$selected_url" "$course_dir"
        
        echo -e "${GREEN}Content downloaded to $course_dir${RESET}"
    else
        echo -e "${RED}Invalid selection${RESET}"
        exit 1
    fi
    
    # Cleanup
    rm -f /tmp/urls.txt /tmp/query.json
}

map_pages() {
    local base_url="$1"
    local output_dir="$2"
    
    http_status=$($CURL_BIN -s -L -o /dev/null -w "%{http_code}" "$base_url")
    if [ "$http_status" -eq 200 ]; then
        pageHtml=$($CURL_BIN -s -L "$base_url")
        echo "$pageHtml" | grep -Eo 'href="[^"]*\/pages\/[^"]*"' | grep -o '"[^"]*"' | tr -d '"' | sort -u > /tmp/urls.txt
        
        while read -r url; do
            if [ ! -z "$url" ]; then
                page_name=$(basename "$url")
                
                if [ "${url#/}" = "$url" ]; then
                    if [ "${url#http}" = "$url" ]; then
                        full_url="${base_url%/}/$url"
                    else
                        full_url="$url"
                    fi
                else
                    full_url="https://ocw.mit.edu$url"
                fi
                
                get_page_content "$full_url" "$output_dir/pages" "$page_name"
            fi
        done < /tmp/urls.txt
        rm -f /tmp/urls.txt
    fi
}

get_page_content() {
    local url="$1"
    local output_dir="$2"
    local page_name="$3"
    
    http_status=$($CURL_BIN -s -L -o /dev/null -w "%{http_code}" "$url")
    if [ "$http_status" -eq 200 ]; then
        mkdir -p "$output_dir"
        pageHtml=$($CURL_BIN -s -L "$url")
        
        # First try to find content between article tags
        content=$(echo "$pageHtml" | tr '\n' ' ' | sed 's/<script.*<\/script>//g' | sed 's/<style.*<\/style>//g' | \
            grep -o '<article class="course-content">.*</article>' | sed 's/<[^>]*>//g')
        
        # If no article content, try main tag
        if [ -z "$content" ]; then
            content=$(echo "$pageHtml" | tr '\n' ' ' | sed 's/<script.*<\/script>//g' | sed 's/<style.*<\/style>//g' | \
                grep -o '<main.*</main>' | sed 's/<[^>]*>//g')
        fi
        
        if [ ! -z "$content" ]; then
            content=$(echo "$content" | sed 's/&nbsp;/ /g' | sed 's/&amp;/\&/g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g' | sed 's/&quot;/"/g')
            content=$(echo "$content" | tr -s ' ' | sed 's/^ *//g' | sed 's/ *$//g')
            echo "$content" > "$output_dir/${page_name}.txt"
        fi
    fi
}

# Main script
if [ $# -eq 0 ]; then
    printf "Enter your search query: "
    read -r query
else
    query="$1"
fi

find_similar_courses "$query"