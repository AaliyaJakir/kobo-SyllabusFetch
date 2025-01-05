#!/usr/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

get_page_content() {
    local url="$1"
    local output_dir="$2"
    local page_name="$3"
    
    http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$url")
    if [ "$http_status" -eq 200 ]; then
        mkdir -p "$output_dir"
        pageHtml=$(curl -s -L "$url")
        
        # Extract content between article tags
        content=$(echo "$pageHtml" | tr '\n' ' ' | sed 's/<script.*?<\/script>//g' | sed 's/<style.*?<\/style>//g' | grep -o -P '<article class="course-content">.*?</article>' | sed 's/<[^>]*>//g')
        
        if [ -z "$content" ]; then
            content=$(echo "$pageHtml" | tr '\n' ' ' | sed 's/<script.*?<\/script>//g' | sed 's/<style.*?<\/style>//g' | grep -o -P '<main.*?>.*?</main>' | sed 's/<[^>]*>//g')
        fi
        
        if [ ! -z "$content" ]; then
            # Clean up content
            content=$(echo "$content" | sed 's/&nbsp;/ /g' | sed 's/&amp;/\&/g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g' | sed 's/&quot;/"/g')
            content=$(echo "$content" | tr -s ' ' | sed 's/^ *//g' | sed 's/ *$//g')
            
            echo "$content" > "$output_dir/${page_name}.txt"
            echo -e "${GREEN}Saved $page_name content${RESET}"
        fi
    fi
}

scan_resources() {
    local base_url="$1"
    local course_dir="$2"
    
    echo -e "${YELLOW}Scanning for available resources...${RESET}"
    
    # Check standard resource paths
    local resource_types=("lecture-notes" "assignments" "exams" "lecture-slides" "readings")
    echo "Available Resources:" > "$course_dir/available_resources.txt"
    echo "===================" >> "$course_dir/available_resources.txt"
    
    for type in "${resource_types[@]}"; do
        local paths=("resources/${type}/" "lists/${type}/" "pages/${type}/")
        for path in "${paths[@]}"; do
            url="${base_url%/}/$path"
            http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$url")
            if [ "$http_status" -eq 200 ]; then
                echo "- $type ($url)" >> "$course_dir/available_resources.txt"
                break
            fi
        done
    done
    
    echo -e "${GREEN}Resource list saved to $course_dir/available_resources.txt${RESET}"
}

map_pages() {
    local base_url="$1"
    local output_dir="$2"
    
    http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$base_url")
    if [ "$http_status" -eq 200 ]; then
        pageHtml=$(curl -s -L "$base_url")
        
        # Get unique page links
        pageUrls=$(echo "$pageHtml" | grep -Eo 'href="[^"]*\/pages\/[^"]*"' | grep -o '"[^"]*"' | tr -d '"' | sort -u)
        
        declare -A processed_pages
        
        while IFS= read -r url; do
            if [ ! -z "$url" ]; then
                page_name=$(basename "$url")
                
                if [ "${processed_pages[$page_name]}" = "1" ]; then
                    continue
                fi
                processed_pages[$page_name]="1"
                
                if [[ "$url" == /* ]]; then
                    full_url="https://ocw.mit.edu$url"
                elif [[ "$url" == http* ]]; then
                    full_url="$url"
                else
                    full_url="${base_url%/}/$url"
                fi
                
                get_page_content "$full_url" "$output_dir/pages" "$page_name"
            fi
        done <<<"$pageUrls"
    fi
}

# Main script
if [ $# -eq 0 ]; then
    read -rep "Enter OCW course URL: " link
else
    link="$1"
fi

if [[ ! "$link" =~ /$ ]]; then
    link="$link/"
fi

if [[ $link == "https://ocw.mit.edu/courses/"* ]]; then
    course_dir=$(basename "$link")
    mkdir -p "$course_dir"
    
    echo -e "${YELLOW}Mapping course content...${RESET}"
    map_pages "$link" "$course_dir"
    scan_resources "$link" "$course_dir"
else
    echo -e "${RED}Invalid MIT OCW link${RESET}"
    exit 1
fi