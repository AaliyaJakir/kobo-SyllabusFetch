import sys
import pickle
import numpy as np
import subprocess
import json

def load_embeddings(embeddings_file):
    """Load pre-computed embeddings from a file"""
    with open(embeddings_file, 'rb') as f:
        data = pickle.load(f)
        return data['embeddings'], data['courses'], data['titles']

def get_embedding_from_shell(query):
    """Get embedding for a query using the shell script"""
    # Path to the shell script
    shell_script_path = "/mnt/onboard/embeddings.sh" 
    # Run the shell script
    result = subprocess.run([shell_script_path, query], capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Shell script failed: {result.stderr}")
    
    # Read the embedding from the output file
    with open("/mnt/onboard/query_embedding.json", "r") as f:
        embedding = json.load(f)
    
    return np.array(embedding)

def search_courses(query, embeddings, courses, titles, top_k=5):
    """Search for courses similar to the query"""
    # Create embedding for the query using the shell script
    query_embedding = get_embedding_from_shell(query)
    
    # Calculate cosine similarity
    similarities = np.dot(embeddings, query_embedding) / (
        np.linalg.norm(embeddings, axis=1) * np.linalg.norm(query_embedding)
    )
    
    # Get top k matches
    top_indices = np.argsort(similarities)[-top_k:][::-1]
    
    results = []
    for idx in top_indices:
        results.append({
            'title': titles[idx],
            'url': courses[idx],
            'similarity': similarities[idx]
        })
    
    return results

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python search_lightweight.py <query> [num_results]")
        sys.exit(1)
    
    query = sys.argv[1]
    num_results = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    
    embeddings, courses, titles = load_embeddings('course_embeddings.pkl')
    results = search_courses(query, embeddings, courses, titles, top_k=num_results)
    
    print(f"\nTop {num_results} courses matching '{query}':\n")
    for i, result in enumerate(results, 1):
        print(f"{i}. {result['title']}")
        print(f"   URL: {result['url']}")
        print(f"   Similarity: {result['similarity']:.3f}\n")