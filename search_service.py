from flask import Flask, request, jsonify
from sentence_transformers import SentenceTransformer
import numpy as np
import json
import faiss
import requests
from bs4 import BeautifulSoup
import os
import subprocess
from datetime import datetime
from shutil import move
from PIL import Image, ImageDraw, ImageFont
import textwrap

app = Flask(__name__)

# Load model and data on startup
print("Loading model and data...")
model = SentenceTransformer('all-MiniLM-L6-v2')

# Load embeddings
with open('mit_embeddings.json', 'r') as f:
    data = json.load(f)

# Prepare FAISS index
embeddings = np.array([item['embedding'] for item in data], dtype='float32')
dimension = len(data[0]['embedding'])
index = faiss.IndexFlatIP(dimension)
index.add(embeddings)

# Add these constants at the top with other imports
EPUB_DIR = "../cwa-book-ingest"
TEMP_DIR = "/tmp/mitocw"

def get_page_content(url):
    try:
        response = requests.get(url)
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Try multiple content extraction strategies
            content = None
            
            # Strategy 1: Try article with course-content class
            article = soup.find('article', class_='course-content')
            if article:
                content = article
            
            # Strategy 2: Try main tag
            if not content:
                content = soup.find('main')
            
            # Strategy 3: Try course-content-section div
            if not content:
                content = soup.find('div', class_='course-content-section')
                
            if content:
                # Remove unwanted elements
                for element in content.find_all(['script', 'style', 'header', 'footer', 'nav']):
                    element.decompose()
                
                # Get text and clean it up
                text = content.get_text()
                text = ' '.join(text.split())
                
                # Clean up HTML entities
                text = text.replace('&nbsp;', ' ')\
                           .replace('&amp;', '&')\
                           .replace('&lt;', '<')\
                           .replace('&gt;', '>')\
                           .replace('&quot;', '"')
                
                return text
            
            return None
    except Exception as e:
        print(f"Error fetching content: {str(e)}")
        return None

def get_course_pages(base_url):
    """Get all available pages for a course."""
    try:
        pages = {}
        response = requests.get(base_url)
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Find all links containing /pages/
            for link in soup.find_all('a', href=True):
                href = link['href']
                if '/pages/' in href:
                    # Get page name from URL
                    page_name = href.split('/pages/')[-1].rstrip('/')
                    if page_name:  # Skip empty page names
                        # Construct full URL
                        if href.startswith('http'):
                            full_url = href
                        elif href.startswith('/'):
                            full_url = f"https://ocw.mit.edu{href}"
                        else:
                            full_url = f"{base_url.rstrip('/')}/pages/{page_name}"
                        
                        # Store page info
                        pages[page_name] = {
                            'url': full_url,
                            'title': link.get_text().strip()
                        }
        
        return pages
    except Exception as e:
        print(f"Error getting course pages: {str(e)}")
        return {}

def format_syllabus(content):
    """Format syllabus content for better readability"""
    sections = {
        'Course Meeting Times': '',
        'Course Description': '',
        'Prerequisites': '',
        'Course Objectives': [],
        'Resources': [],
        'Assessment': ''
    }
    
    current_section = None
    lines = content.split('. ')
    
    for line in lines:
        line = line.strip()
        if line in sections:
            current_section = line
            continue
            
        if current_section:
            if current_section in ['Course Objectives', 'Resources']:
                if line:
                    sections[current_section].append(line)
            else:
                sections[current_section] += line + '. '
    
    # Format the content
    formatted = f"""# MIT Private Pilot Ground School Syllabus

## Course Meeting Times
{sections['Course Meeting Times']}

## Course Description
{sections['Course Description']}

## Prerequisites
{sections['Prerequisites']}

## Course Objectives
"""
    
    # Add objectives as bullet points
    for obj in sections['Course Objectives']:
        if obj:
            formatted += f"- {obj}\n"
    
    formatted += "\n## Resources\n"
    # Add resources as bullet points
    for resource in sections['Resources']:
        if resource:
            formatted += f"- {resource}\n"
    
    formatted += f"\n## Assessment\n{sections['Assessment']}"
    
    return formatted

def create_cover_image(title, temp_dir):
    """Create a simple cover image with the title"""
    # Create a new image with a white background
    width = 1200
    height = 1600
    img = Image.new('RGB', (width, height), 'white')
    draw = ImageDraw.Draw(img)
    
    try:
        # Try to use a nice font if available
        font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", 60)
        small_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif.ttf", 40)
    except:
        # Fallback to default font
        font = ImageFont.load_default()
        small_font = ImageFont.load_default()
    
    # Wrap title text
    wrapped_text = textwrap.fill(title, width=30)
    
    # Calculate text size and position
    text_bbox = draw.textbbox((0, 0), wrapped_text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[1]
    
    # Draw title
    x = (width - text_width) // 2
    y = (height - text_height) // 2 - 100
    draw.text((x, y), wrapped_text, font=font, fill='black', align='center')
    
    # Draw MIT OCW text
    ocw_text = "MIT OpenCourseWare"
    text_bbox = draw.textbbox((0, 0), ocw_text, font=small_font)
    text_width = text_bbox[2] - text_bbox[0]
    x = (width - text_width) // 2
    draw.text((x, y + text_height + 60), ocw_text, font=small_font, fill='#666666')
    
    # Save the image
    cover_path = f"{temp_dir}/cover.png"
    img.save(cover_path)
    return cover_path

def create_epub(content, metadata, temp_dir=TEMP_DIR):
    """Create an EPUB file from content"""
    try:
        # Create temp directory if it doesn't exist
        os.makedirs(temp_dir, exist_ok=True)
        
        # Clean the title for YAML
        clean_title = metadata['title'].replace(':', ' -')  # Replace problematic characters
        
        # Create cover image
        cover_path = create_cover_image(clean_title, temp_dir)
        
        # Create a temporary markdown file
        md_file = f"{temp_dir}/{metadata['filename']}.md"
        with open(md_file, 'w', encoding='utf-8') as f:
            # Add YAML metadata for pandoc
            f.write(f"""---
title: "{clean_title}"
author: "MIT OpenCourseWare"
date: "{datetime.now().strftime('%Y-%m-%d')}"
---

{content}
""")
        
        # Create epub file
        epub_file = f"{temp_dir}/{metadata['filename']}.epub"
        
        # Ensure EPUB_DIR exists
        os.makedirs(EPUB_DIR, exist_ok=True)
        
        # Run pandoc with cover image
        result = subprocess.run([
            'pandoc',
            '--from', 'markdown',
            '--to', 'epub',
            '-o', epub_file,
            '--epub-cover-image', cover_path,
            '--toc',
            '--toc-depth=2',
            '-s',
            md_file
        ], capture_output=True, text=True)
        
        if result.returncode != 0:
            print(f"Pandoc error: {result.stderr}")
            return None
            
        # Move to final destination
        final_path = os.path.join(EPUB_DIR, f"{metadata['filename']}.epub")
        move(epub_file, final_path)
        
        # Cleanup
        os.remove(md_file)
        os.remove(cover_path)
        
        return final_path
    except Exception as e:
        print(f"Error creating EPUB: {str(e)}")
        return None

@app.route('/search', methods=['POST'])
def search():
    try:
        query = request.json['query']
        
        # Generate embedding for query
        query_vector = model.encode([query])[0]
        query_vector = np.array([query_vector], dtype='float32')
        
        # Search using FAISS
        k = 5  # number of results to return
        D, I = index.search(query_vector, k)
        
        # Format results
        results = []
        for idx, (distance, i) in enumerate(zip(D[0], I[0])):
            results.append({
                'url': data[i]['url'],
                'text': data[i]['text'],
                'score': float(distance)
            })
        
        return jsonify({
            'success': True,
            'results': results
        })
    
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

@app.route('/fetch-content', methods=['POST'])
def fetch_content():
    try:
        url = request.json['url']
        page = request.json.get('page')
        format = request.json.get('format', 'json')
        
        if not url.startswith('https://ocw.mit.edu/courses/'):
            return jsonify({
                'success': False,
                'error': 'Invalid MIT OCW URL'
            })
        
        pages = get_course_pages(url)
        
        if not page:
            page = 'syllabus'
        
        if page in pages:
            content = get_page_content(pages[page]['url'])
            if content:
                if format == 'epub':
                    # Get course code from URL
                    course_code = url.split('courses/')[-1].split('/')[0]  # e.g., "16-687"
                    course_name = pages[page]['title']
                    
                    # Create a safe but descriptive filename
                    safe_filename = f"{course_code}_{page}"
                    if page == "syllabus":
                        safe_filename = f"{course_code}_syllabus"
                    
                    metadata = {
                        'title': f"{course_code} - {course_name}",
                        'filename': safe_filename
                    }
                    
                    # Format content as markdown with proper headers
                    formatted_content = f"""# {course_code} - {course_name}

## Course Content

{content}

## Available Pages

The following pages are also available for this course:

"""
                    # Add list of other available pages
                    for p_name, p_info in pages.items():
                        if p_name != page:
                            formatted_content += f"- {p_info['title']}\n"
                    
                    # Create and move the EPUB
                    epub_path = create_epub(formatted_content, metadata)
                    if epub_path:
                        return jsonify({
                            'success': True,
                            'message': f'EPUB created at {epub_path}',
                            'epub_path': epub_path
                        })
                    else:
                        return jsonify({
                            'success': False,
                            'error': 'Failed to create EPUB'
                        })
                
                # Original text/json response handling...
                if format == 'text':
                    formatted_content = f"""# {pages[page]['title']}\n\n{content}"""
                    return formatted_content, 200, {'Content-Type': 'text/plain; charset=utf-8'}
                
                return jsonify({
                    'success': True,
                    'content': content,
                    'resources': get_available_resources(url),
                    'available_pages': pages,
                    'current_page': page
                })
        
        return jsonify({
            'success': False,
            'error': 'Could not fetch content',
            'available_pages': pages
        })
            
    except Exception as e:
        return jsonify({
            'success': False,
            'error': str(e)
        })

def get_available_resources(base_url):
    """Get list of available resources for a course."""
    try:
        resources = []
        
        # Check download page
        download_url = f"{base_url.rstrip('/')}/download/"
        response = requests.get(download_url)
        if response.status_code == 200:
            soup = BeautifulSoup(response.text, 'html.parser')
            
            # Common resource types to look for
            resource_types = ["Lecture Videos", "Assignments", "Exams", "Lecture Notes"]
            
            for resource in resource_types:
                if resource.lower() in response.text.lower():
                    resources.append(resource)
        
        # Also check standard resource paths
        paths = ["resources/", "lists/", "pages/"]
        resource_types = ["lecture-notes", "assignments", "exams", "lecture-slides", "readings"]
        
        for type_ in resource_types:
            for path in paths:
                url = f"{base_url.rstrip('/')}/{path}{type_}/"
                response = requests.head(url)
                if response.status_code == 200:
                    display_name = type_.replace('-', ' ').title()
                    if display_name not in resources:
                        resources.append(display_name)
                    break
        
        return resources
        
    except Exception as e:
        print(f"Error getting resources: {str(e)}")
        return []

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)