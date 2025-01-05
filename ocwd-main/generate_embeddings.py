from sentence_transformers import SentenceTransformer
import json
import re
from tqdm import tqdm

def clean_url(url):
    # Extract course number and name from URL
    match = re.search(r'courses/([^/]+)', url)
    if match:
        return match.group(1).replace('-', ' ')
    return url

def main():
    # Load the model
    print("Loading model...")
    model = SentenceTransformer('all-MiniLM-L6-v2')
    
    # Read URLs from file
    print("Reading courses...")
    with open('mit_courses.txt', 'r') as f:
        lines = f.readlines()
    
    # Clean and prepare courses
    courses = []
    for line in lines:
        if 'https://' in line:
            url = line.strip()
            course_text = clean_url(url)
            courses.append({
                'url': url,
                'text': course_text
            })
    
    # Generate embeddings
    print("Generating embeddings...")
    embeddings = []
    for course in tqdm(courses):
        vector = model.encode(course['text'])
        embeddings.append({
            'url': course['url'],
            'text': course['text'],
            'embedding': vector.tolist()
        })
    
    # Save embeddings
    print("Saving embeddings...")
    with open('mit_embeddings.json', 'w') as f:
        json.dump(embeddings, f)

if __name__ == "__main__":
    main()