#!/bin/sh

echo "Generating embeddings for courses..."

# Define paths
CURL_BIN="curl"  # Assuming curl is installed and available in your PATH
JQ_BIN="jq"      # Assuming jq is installed and available in your PATH
COURSES_FILE="mit_courses.txt"
EMBEDDINGS_OUTPUT="course_embeddings.json"
API_URL="https://roadmapproduction.openai.azure.com/openai/deployments/text-embedding-ada-002/embeddings?api-version=2023-05-15"
API_KEY="d82038d046244e8eb6c88ffb39f613e9"

# Check if dependencies exist
if ! command -v $CURL_BIN &> /dev/null; then
    echo "Error: curl is not installed."
    exit 1
fi

if ! command -v $JQ_BIN &> /dev/null; then
    echo "Error: jq is not installed."
    exit 1
fi

# Check if courses file exists
if [ ! -f "$COURSES_FILE" ]; then
    echo "Error: Courses file $COURSES_FILE not found."
    exit 1
fi

# Initialize output file
echo "[]" > "$EMBEDDINGS_OUTPUT"

# Process each course URL
while IFS= read -r line; do
    # Extract the course title from the URL
    course_url=$(echo "$line" | xargs)
    if [ -z "$course_url" ]; then
        continue
    fi
    course_title=$(basename "$course_url" | sed 's/-/ /g')

    # Create JSON data with the course title
    JSON_DATA=$(cat <<EOF
{
  "input": "$course_title"
}
EOF
)

    # Send request and get response
    RESPONSE=$($CURL_BIN -s "$API_URL" \
        -H "Content-Type: application/json" \
        -H "api-key: $API_KEY" \
        -d "$JSON_DATA")

    # Check if curl succeeded
    if [ $? -ne 0 ]; then
        echo "Error: Failed to make API request for $course_title"
        continue
    fi

    # Extract embedding and append to output file
    EMBEDDING=$($JQ_BIN '.data[0].embedding' <<< "$RESPONSE")
    if [ -z "$EMBEDDING" ]; then
        echo "Error: Failed to extract embedding for $course_title"
        continue
    fi

    # Append to the JSON array in the output file
    $JQ_BIN --argjson embedding "$EMBEDDING" --arg title "$course_title" --arg url "$course_url" \
        '. += [{"title": $title, "url": $url, "embedding": $embedding}]' "$EMBEDDINGS_OUTPUT" > tmp.$$.json && mv tmp.$$.json "$EMBEDDINGS_OUTPUT"

    echo "Processed: $course_title"
done < "$COURSES_FILE"

echo "Embeddings generation completed. Saved to $EMBEDDINGS_OUTPUT"