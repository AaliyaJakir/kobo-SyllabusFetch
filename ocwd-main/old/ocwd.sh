#!/usr/bin/bash

#################################
# Title: OCWD                   #
# Author: Aniruddha Mukherjee   #
# Last edited: 12 Sept. 2024    #
#################################

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

# Trims whitespace
trim() {
    trimmed=$(awk '{$1=$1};1' <<<"$1")
    echo "$trimmed"
}

show_details() {
    echo -e "${YELLOW}:::::::::::::::::::::::::::::::::::"
    echo -e "╰(*°▽°*)╯ Course Details"
    echo -e ":::::::::::::::::::::::::::::::::::${RESET}"
    # Title
    titleLine=$(echo "$1" | grep '<title>')
    titleLine=$(trim "$titleLine")
    titleLine=$(echo "$titleLine" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p')
    title=$(awk -F "|" '{print $1}' <<<"$titleLine")
    echo -e "${GREEN}- Title: $title"

    # Instructor
    instructorLine=$(echo "$1" | grep -m 1 '<a class="course-info-instructor strip-link-offline"  href=".*">')
    instructorLine=$(trim "$instructorLine")
    instructorLine=$(echo "$instructorLine" | sed -n 's/.*<a[^>]*>\(.*\)<\/a>.*/\1/p')
    echo -e "- Instructor: $instructorLine"
}

show_additional_details() {
    additionalDetailsLine=$(echo "$1" | grep '<span class="course-number-term-detail">')
    additionalDetailsLine=$(trim "$additionalDetailsLine")
    additionalDetails=$(echo "$additionalDetailsLine" | sed -n 's/.*<span[^>]*>\(.*\)<\/span>.*/\1/p')
    courseId=$(echo "$additionalDetails" | awk -F "|" '{print $1}')
    courseId=$(trim "$courseId")
    courseSem=$(echo "$additionalDetails" | awk -F "|" '{print $2}')
    courseSem=$(trim "$courseSem")
    courseLevel=$(echo "$additionalDetails" | awk -F "|" '{print $3}')
    courseLevel=$(trim "$courseLevel")
    echo -e "- ID: $courseId"
    echo -e "- Semester: $courseSem"
    echo -e "- Level: $courseLevel${RESET}"
}

show_resources() {
    echo -e "${YELLOW}::::::::::::::::::::::::::::::::"
    echo -e "╰(*°▽°*)╯ Available Resources"
    echo -e "::::::::::::::::::::::::::::::::${RESET}"
    download="download"
    if [[ $1 =~ /$ ]]; then
        downloadPageLink="$1$download/"
    else
        downloadPageLink="$1/download/"
    fi
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$downloadPageLink")
    if [ "$http_status" -eq 200 ]; then
        downloadPageHtml=$(curl -s "$downloadPageLink")
        keys=("Lecture Videos" "Assignments" "Exams" "Lecture Notes")
        index=0
        for key in "${keys[@]}"; do
            if [[ "$downloadPageHtml" =~ $key ]]; then
                resourceList["$index"]="$key"
                ((index++))
                echo -e "${GREEN}$index. $key${RESET}"
            fi
        done
    else
        echo -e "${RED}E: Error $http_status, could not fetch reosources${RESET}"
        exit 1
    fi
}

get_options() {
    echo -e "${YELLOW}Enter the index of the desired resource for download"
    echo -e "=>Use commas for multiple indices"
    echo -e "=>Enter A for downloading all resources"
    echo -e "=>Example: 1,2${RESET}"

    correctInputFlag=0
    while [ "$correctInputFlag" -ne 1 ]; do
        read -rep "Input: " option

        case ${#option} in
        "0") echo -e "${RED}E: Input cannot be empty!${RESET}" ;;
        "1")
            if [[ $option == 'a' || $option == 'A' ]]; then
                index=0
                for item in "${resourceList[@]}"; do
                    targetKeys["$index"]="$item"
                    ((index++))
                done
                correctInputFlag=1
            else
                if ((option > 0 && option <= ${#resourceList[@]})); then
                    resourceIndex=$((option - 1))
                    targetKeys["0"]="${resourceList["$resourceIndex"]}"
                    correctInputFlag=1
                else
                    echo -e "${RED}E: Invalid Index${RESET}"
                fi
            fi
            ;;
        2) echo -e "${RED}E: Invalid Index${RESET}" ;;
        *)
            if [[ $option == 'All' || $option == 'all' ]]; then
                index=0
                for item in "${resourceList[@]}"; do
                    targetKeys["$index"]="$item"
                    ((index++))
                done
                correctInputFlag=1
            else
                IFS=',' read -ra temptargetKeys <<<"$option"
                index=0
                for element in "${temptargetKeys[@]}"; do
                    if ((element > 0 && element <= ${#resourceList[@]})); then
                        resourceIndex=$((element - 1))
                        targetKeys["$index"]="${resourceList["$resourceIndex"]}"
                        ((index++))
                        correctInputFlag=1
                    else
                        correctInputFlag=0
                        echo -e "${RED}E: Invalid index: $element${RESET}"
                        break
                    fi
                done
            fi
            ;;
        esac
    done
}

get_files() {
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$1")
    if [ "$http_status" -eq 200 ]; then
        basePageHtml=$(curl -s "$1")
        
        # First check if there are PDF files to download
        downloadUrls=$(echo "$basePageHtml" | grep -Eo 'href="[^"]+"')
        downloadUrls=$(echo "$downloadUrls" | grep -o '"[^"]\+"')
        downloadUrls=$(echo "$downloadUrls" | grep -oE '/[^"]+')

        if [[ $2 =~ 'LVideos' ]]; then
            downloadUrls=$(echo "$downloadUrls" | grep '.mp4$')
            extension=".mp4"
        else
            downloadUrls=$(echo "$downloadUrls" | grep '.pdf$')
            extension=".pdf"
        fi

        # If no PDFs found and this is an assignments page, get the webpage content
        if [[ -z "$downloadUrls" ]] && [[ $2 =~ 'Assignments' ]]; then
            echo -e "${YELLOW}No downloadable files found. Saving webpage content...${RESET}"
            get_page_content "$1" "$2" "webpage_content"
            return
        fi

        # Converting the multi-line variable into a list
        downloadUrlList=()
        while IFS= read -r url; do
            downloadUrlList+=("$url")
        done <<<"$downloadUrls"

        if [ ${#downloadUrlList[@]} -eq 0 ]; then
            if [[ $2 =~ 'Assignments' ]] || [[ $2 =~ 'Syllabus' ]]; then
                echo -e "${YELLOW}No downloadable files found. Content may be directly on the webpage.${RESET}"
                get_page_content "$1" "$2" "webpage_content"
            else
                echo -e "${RED}No downloadable files found.${RESET}"
            fi
            return
        fi

        baseLink="https://ocw.mit.edu"

        # the following part deals with downloads
        index=1
        mkdir -p "$2/"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Directory '$2' created successfully.${RESET}"
        else
            echo -e "${RED}E: Failed to create directory '$2'.${RESET}"
        fi
        echo -e "${YELLOW}How would you like the files to be downloded?"
        echo -e "1. Serially (one after another)"
        echo -e "2. Parallely (multiple files simultaneously)${RESET}"
        total_items=${#downloadUrlList[@]}
        correctFlag=0
        while [ "$correctFlag" -eq 0 ]; do
            read -rep "Input (1 or 2): " downloadOption
            case "$downloadOption" in
            "1")
                correctFlag=1
                # serial download
                for url in "${downloadUrlList[@]}"; do
                    filename=$(basename "$2")

                    if [[ $2 =~ 'LVideos' ]]; then
                        url="${url:2}"
                        curl -s -L -o "./$2/$filename$index$extension" "https://$url"
                    else
                        curl -s -o "./$2/$filename$index$extension" "$baseLink$url"
                    fi
                    percentage=$((index * 100 / total_items))
                    bar_length=$((index * 50 / total_items))
                    progress_bar="["
                    for ((j = 0; j < bar_length; j++)); do
                        progress_bar+="="
                    done
                    for ((j = bar_length; j < 50; j++)); do
                        progress_bar+=" "
                    done
                    progress_bar+="]"

                    # Print the progress bar and percentage
                    printf "\rProgress: %3d%% %s" "$percentage" "$progress_bar"
                    ((index++))
                done
                printf "\n"
                ;;
            "2")
                correctFlag=1
                # parallel download
                for url in "${downloadUrlList[@]}"; do
                    filename=$(basename "$2")
                    if [[ $2 =~ 'LVideos' ]]; then
                        url="${url:2}"
                        curl -s -L -o "./$2/$filename$index$extension" "https://$url" &
                    else
                        curl -s -o "./$2/$filename$index$extension" "$baseLink$url" &
                    fi
                    ((index++))
                done
                wait
                ;;
            *) echo -e "${RED}E: The only valid inputs are 1 & 2${RESET}" ;;
            esac
        done
    else
        echo -e "${RED}E: Error $http_status, could not load $1${RESET}"
    fi
}

find_resource_path() {
    local base_url="$1"
    local resource_type="$2"
    local paths=("resources/${resource_type,,}/" "lists/${resource_type,,}/" "pages/${resource_type,,}/")
    
    for path in "${paths[@]}"; do
        url="${base_url%/}/$path"
        http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$url")
        if [ "$http_status" -eq 200 ]; then
            # Check if the page actually has PDF links
            pageHtml=$(curl -s -L "$url")
            if echo "$pageHtml" | grep -q '\.pdf"'; then
                echo "$path"
                return 0
            fi
        fi
    done
    echo ""
    return 1
}

find_pdf_links() {
    local url="$1"
    local pageHtml=$(curl -s -L "$url")
    
    # Extract all hrefs that might be PDFs or lead to PDFs
    echo "$pageHtml" | grep -o -E 'href="[^"]*\.(pdf|html?)"' | sed 's/href=//g' | tr -d '"' | while read -r link; do
        # Skip empty lines
        [ -z "$link" ] && continue
        
        # Handle relative URLs
        if [[ "$link" == /* ]]; then
            link="https://ocw.mit.edu$link"
        elif [[ ! "$link" == http* ]]; then
            link="${url%/}/$link"
        fi
        
        # For HTML links, check if they redirect to PDF
        if [[ "$link" == *.html ]] || [[ "$link" == *.htm ]]; then
            redirect_url=$(curl -s -L -w '%{url_effective}' -o /dev/null "$link")
            if [[ "$redirect_url" == *.pdf ]]; then
                echo "$redirect_url"
            fi
            continue
        fi
        
        # For PDF links, verify they exist
        if [[ "$link" == *.pdf ]]; then
            http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$link")
            if [ "$http_status" -eq 200 ]; then
                echo "$link"
            fi
        fi
    done | sort -u
}

scan_resources() {
    local base_url="$1"
    local course_dir="$2"
    declare -A resource_paths
    local available_resources=()
    
    echo -e "${YELLOW}Scanning for available resources...${RESET}"
    
    # First check the course root URL for PDFs
    echo -e "${YELLOW}Checking course root for PDFs...${RESET}"
    local root_pdfs=$(find_pdf_links "$base_url")
    if [ ! -z "$root_pdfs" ]; then
        echo -e "${GREEN}Found PDFs in course root${RESET}"
        resource_paths["Course Materials"]=""
        available_resources+=("Course Materials")
    fi
    
    # Then check standard paths
    local resource_types=("lecture-notes" "assignments" "exams" "lecture-slides" "readings")
    for type in "${resource_types[@]}"; do
        echo -e "${YELLOW}Checking $type...${RESET}"
        local paths=("resources/${type}/" "lists/${type}/" "pages/${type}/")
        for path in "${paths[@]}"; do
            url="${base_url%/}/$path"
            http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$url")
            if [ "$http_status" -eq 200 ]; then
                # Check if the page has PDF links
                local pdf_links=$(find_pdf_links "$url")
                if [ ! -z "$pdf_links" ]; then
                    echo -e "${GREEN}Found PDFs in $path${RESET}"
                    display_name=$(echo "$type" | tr '-' ' ' | sed 's/\b\(.\)/\u\1/g')
                    resource_paths["$display_name"]="$path"
                    available_resources+=("$display_name")
                    break
                fi
            fi
        done
    done
    
    # Then check general resources
    echo -e "${YELLOW}Checking general resources...${RESET}"
    local resources_url="${base_url%/}/resources/"
    http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$resources_url")
    if [ "$http_status" -eq 200 ]; then
        local pdf_links=$(find_pdf_links "$resources_url")
        if [ ! -z "$pdf_links" ]; then
            echo -e "${GREEN}Found PDFs in resources/${RESET}"
            resource_paths["General Resources"]="resources/"
            available_resources+=("General Resources")
        fi
    fi
    
    # Present available resources to user
    if [ ${#available_resources[@]} -eq 0 ]; then
        echo -e "${RED}No downloadable resources found${RESET}"
        return
    fi
    
    echo -e "\n${GREEN}Available resources:${RESET}"
    for i in "${!available_resources[@]}"; do
        local resource="${available_resources[$i]}"
        echo "$((i+1)). $resource"
        # Show number of PDFs in each category
        if [ -z "${resource_paths[$resource]}" ]; then
            local pdf_count=$(echo "$root_pdfs" | grep -c "^")
            echo "   └── Found $pdf_count PDF files at course root"
        else
            local category_pdfs=$(find_pdf_links "${base_url%/}/${resource_paths[$resource]}")
            local pdf_count=$(echo "$category_pdfs" | grep -c "^")
            echo "   └── Found $pdf_count PDF files in ${resource_paths[$resource]}"
        fi
    done
    
    # Get user selection
    echo -e "${YELLOW}Enter the index of the desired resource for download"
    echo "=>Use commas for multiple indices"
    echo "=>Enter A for downloading all resources"
    echo -e "=>Example: 1,2${RESET}"
    read -rep "Input: " selection
    
    # Create download directory
    mkdir -p "$course_dir"
    
    # Process selection
    if [[ "$selection" == "A" || "$selection" == "a" ]]; then
        for resource in "${available_resources[@]}"; do
            echo -e "${YELLOW}✨ Fetching $resource${RESET}"
            if [ -z "${resource_paths[$resource]}" ]; then
                # For root PDFs
                download_pdfs "$base_url" "$course_dir/${resource// /}"
            else
                download_pdfs "${base_url%/}/${resource_paths[$resource]}" "$course_dir/${resource// /}"
            fi
        done
    else
        IFS=',' read -ra indices <<< "$selection"
        for index in "${indices[@]}"; do
            index=$((index-1))
            if [ $index -ge 0 ] && [ $index -lt ${#available_resources[@]} ]; then
                resource="${available_resources[$index]}"
                echo -e "${YELLOW}✨ Fetching $resource${RESET}"
                if [ -z "${resource_paths[$resource]}" ]; then
                    # For root PDFs
                    download_pdfs "$base_url" "$course_dir/${resource// /}"
                else
                    download_pdfs "${base_url%/}/${resource_paths[$resource]}" "$course_dir/${resource// /}"
                fi
            fi
        done
    fi
}

download_pdfs() {
    local url="$1"
    local output_dir="$2"
    
    mkdir -p "$output_dir"
    
    # Get all PDF links
    local pdf_links=$(find_pdf_links "$url")
    
    # Download each PDF
    while IFS= read -r pdf_link; do
        [ -z "$pdf_link" ] && continue
        
        # Get filename from URL
        local filename=$(basename "$pdf_link")
        if [[ ! "$filename" == *.pdf ]]; then
            filename="${filename}.pdf"
        fi
        
        echo -e "${YELLOW}Downloading $filename...${RESET}"
        curl -s -L "$pdf_link" -o "$output_dir/$filename"
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✨ Downloaded $filename${RESET}"
        else
            echo -e "${RED}Failed to download $filename${RESET}"
        fi
    done <<< "$pdf_links"
}

get_resources() {
    scan_resources "$link" "$course_dir"
}

get_page_content() {
    local url="$1"
    local output_dir="$2"
    local page_name="$3"
    
    http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$url")
    if [ "$http_status" -eq 200 ]; then
        # Create directory if it doesn't exist
        mkdir -p "$output_dir"
        
        # Get the page content with redirect following
        pageHtml=$(curl -s -L "$url")
        
        # Extract content between article tags, handling multiline
        content=$(echo "$pageHtml" | tr '\n' ' ' | sed 's/<script.*?<\/script>//g' | sed 's/<style.*?<\/style>//g' | grep -o -P '<article class="course-content">.*?</article>' | sed 's/<[^>]*>//g')
        
        if [ -z "$content" ]; then
            # Try extracting from main tag if article not found
            content=$(echo "$pageHtml" | tr '\n' ' ' | sed 's/<script.*?<\/script>//g' | sed 's/<style.*?<\/style>//g' | grep -o -P '<main.*?>.*?</main>' | sed 's/<[^>]*>//g')
        fi
        
        if [ ! -z "$content" ]; then
            # Clean up the content
            content=$(echo "$content" | sed 's/&nbsp;/ /g' | sed 's/&amp;/\&/g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g' | sed 's/&quot;/"/g')
            content=$(echo "$content" | tr -s ' ' | sed 's/^ *//g' | sed 's/ *$//g')
            content=$(echo "$content" | awk '{gsub(/[[:space:]]+/," ")}1' | sed 's/[[:space:]]*$//')
            
            # Add some basic formatting
            content=$(echo -e "# $page_name\n\n$content")
            
            # Save to file
            echo "$content" > "$output_dir/${page_name}.txt"
            echo -e "${GREEN}✨ Saved $page_name content to $output_dir/${page_name}.txt${RESET}"
        else
            # Try one more time with a more lenient approach
            content=$(echo "$pageHtml" | tr '\n' ' ' | sed 's/<script.*?<\/script>//g' | sed 's/<style.*?<\/style>//g' | sed 's/<header.*?<\/header>//g' | sed 's/<footer.*?<\/footer>//g' | sed 's/<nav.*?<\/nav>//g' | grep -o -P '<div class="course-content-section">.*?</div>' | sed 's/<[^>]*>//g')
            
            if [ ! -z "$content" ]; then
                # Clean up the content
                content=$(echo "$content" | sed 's/&nbsp;/ /g' | sed 's/&amp;/\&/g' | sed 's/&lt;/</g' | sed 's/&gt;/>/g' | sed 's/&quot;/"/g')
                content=$(echo "$content" | tr -s ' ' | sed 's/^ *//g' | sed 's/ *$//g')
                content=$(echo "$content" | awk '{gsub(/[[:space:]]+/," ")}1' | sed 's/[[:space:]]*$//')
                
                # Add some basic formatting
                content=$(echo -e "# $page_name\n\n$content")
                
                echo "$content" > "$output_dir/${page_name}.txt"
                echo -e "${GREEN}✨ Saved $page_name content to $output_dir/${page_name}.txt${RESET}"
            else
                echo -e "${RED}E: Could not extract content from $page_name page${RESET}"
            fi
        fi
    else
        echo -e "${RED}E: Error $http_status, could not access $page_name page${RESET}"
    fi
}

map_pages() {
    local base_url="$1"
    local output_dir="$2"
    
    http_status=$(curl -s -L -o /dev/null -w "%{http_code}" "$base_url")
    if [ "$http_status" -eq 200 ]; then
        # Get the course homepage
        pageHtml=$(curl -s -L "$base_url")
        
        # Extract links to pages
        echo "Available course content:" > "$output_dir/content_map.txt"
        echo "========================" >> "$output_dir/content_map.txt"
        
        # Get all links containing /pages/
        pageUrls=$(echo "$pageHtml" | grep -Eo 'href="[^"]*\/pages\/[^"]*"' | grep -o '"[^"]*"' | tr -d '"')
        
        while IFS= read -r url; do
            if [ ! -z "$url" ]; then
                # Extract page name from URL
                page_name=$(basename "$url")
                echo "- $page_name" >> "$output_dir/content_map.txt"
                
                # Construct full URL properly
                if [[ "$url" == /* ]]; then
                    # If URL starts with /, append to base domain
                    full_url="https://ocw.mit.edu$url"
                elif [[ "$url" == http* ]]; then
                    # If URL is already absolute, use as is
                    full_url="$url"
                else
                    # Otherwise append to base URL
                    full_url="${base_url%/}/$url"
                fi
                
                # Save the page content
                get_page_content "$full_url" "$output_dir/pages" "$page_name"
            fi
        done <<<"$pageUrls"
        
        echo -e "${GREEN}✨ Created content map at $output_dir/content_map.txt${RESET}"
    else
        echo -e "${RED}E: Error $http_status, could not access course homepage${RESET}"
    fi
}

# Starting point

if [ $# -eq 0 ]; then
    echo "ocwd Copyright (C) 2024 Aniruddha Mukherjee<amkhrjee@gmail.com>"
    echo "This program comes with ABSOLUTELY NO WARRANTY"
    echo "This is free software, and you are welcome to"
    echo "redistribute it under certain conditions."
    echo ""
    read -rep "Please enter the link to course homepage: " link
fi
if [ $# -eq 1 ]; then
    link="$1"
fi
if [ $# -gt 1 ]; then
    echo -e "${RED}E: More than one argument passed${RESET}"
    echo "Usage: ocwd <link>"
    exit 1
fi

# trims the link
link=$(awk '{$1=$1};1' <<<"$link")

# Ensure the link ends with a trailing slash
if [[ ! "$link" =~ /$ ]]; then
    link="$link/"
fi

if [[ $link == "https://ocw.mit.edu/courses/"* ]]; then
    http_status=$(curl -s -o /dev/null -w "%{http_code}" "$link")
    echo "Debug - http_status: '$http_status'"
    if [ "$http_status" -eq 200 ]; then
        pageHtml=$(curl -s "$link")
        show_details "$pageHtml"
        show_additional_details "$pageHtml"
        resourceList=()
        show_resources "$link"
        
        # Create course directory using course number
        course_dir=$(basename "$link")
        mkdir -p "$course_dir"
        
        # Map and save all page content
        echo -e "${YELLOW}Mapping course content...${RESET}"
        map_pages "$link" "$course_dir"
        
        targetKeys=()
        get_resources
    else
        echo -e "${RED}E: Error $http_status, could not parse website${RESET}"
        exit 1
    fi
else
    echo -e "${RED}E: Please enter a valid MIT OCW link${RESET}"
    exit 1
fi