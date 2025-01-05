import os
import numpy as np
import pandas as pd
from sentence_transformers import SentenceTransformer
from tqdm import tqdm
import pickle
import argparse

class CourseSearch:
    def __init__(self, model_name='all-MiniLM-L6-v2'):
        self.model = SentenceTransformer(model_name)
        self.embeddings_file = 'course_embeddings.pkl'
        self.courses_file = 'mit_courses.txt'
        self.courses = []
        self.embeddings = None
        
    def load_courses(self):
        """Load courses from the text file"""
        if not os.path.exists(self.courses_file):
            raise FileNotFoundError(f"Courses file {self.courses_file} not found. Run get_courses.sh first.")
        
        with open(self.courses_file, 'r') as f:
            self.courses = [line.strip() for line in f if line.strip()]
            
        # Convert URLs to readable titles
        self.titles = [url.split('/')[-1].replace('-', ' ') for url in self.courses]
        
    def create_embeddings(self):
        """Create embeddings for all courses"""
        print("Creating embeddings for all courses...")
        self.embeddings = self.model.encode(self.titles, show_progress_bar=True)
        
        # Save embeddings to file
        with open(self.embeddings_file, 'wb') as f:
            pickle.dump({
                'embeddings': self.embeddings,
                'courses': self.courses,
                'titles': self.titles
            }, f)
        print(f"Saved embeddings for {len(self.courses)} courses")
            
    def load_embeddings(self):
        """Load pre-computed embeddings"""
        if not os.path.exists(self.embeddings_file):
            self.load_courses()
            self.create_embeddings()
        else:
            with open(self.embeddings_file, 'rb') as f:
                data = pickle.load(f)
                self.embeddings = data['embeddings']
                self.courses = data['courses']
                self.titles = data['titles']
    
    def search(self, query, top_k=5):
        """Search for courses similar to the query"""
        # Create embedding for the query
        query_embedding = self.model.encode([query])[0]
        
        # Calculate cosine similarity
        similarities = np.dot(self.embeddings, query_embedding) / (
            np.linalg.norm(self.embeddings, axis=1) * np.linalg.norm(query_embedding)
        )
        
        # Get top k matches
        top_indices = np.argsort(similarities)[-top_k:][::-1]
        
        results = []
        for idx in top_indices:
            results.append({
                'title': self.titles[idx],
                'url': self.courses[idx],
                'similarity': similarities[idx]
            })
            
        return results

def main():
    parser = argparse.ArgumentParser(description='Search MIT OCW courses')
    parser.add_argument('--query', '-q', type=str, help='Search query')
    parser.add_argument('--num_results', '-n', type=int, default=5, help='Number of results to show')
    parser.add_argument('--rebuild', '-r', action='store_true', help='Rebuild embeddings')
    args = parser.parse_args()
    
    searcher = CourseSearch()
    
    if args.rebuild or not os.path.exists(searcher.embeddings_file):
        searcher.load_courses()
        searcher.create_embeddings()
    else:
        searcher.load_embeddings()
    
    if args.query:
        results = searcher.search(args.query, args.num_results)
        print(f"\nTop {args.num_results} courses matching '{args.query}':\n")
        for i, result in enumerate(results, 1):
            print(f"{i}. {result['title']}")
            print(f"   URL: {result['url']}")
            print(f"   Similarity: {result['similarity']:.3f}\n")
    else:
        while True:
            query = input("\nEnter your search query (or 'q' to quit): ")
            if query.lower() == 'q':
                break
                
            results = searcher.search(query)
            print(f"\nTop 5 courses matching '{query}':\n")
            for i, result in enumerate(results, 1):
                print(f"{i}. {result['title']}")
                print(f"   URL: {result['url']}")
                print(f"   Similarity: {result['similarity']:.3f}\n")

if __name__ == "__main__":
    main()
