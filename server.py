import mysql.connector
from flask import Flask, request, jsonify
from flask_cors import CORS
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
import base64
import nltk

# Download NLTK data if not already installed
nltk.download('punkt', quiet=True)

# Initialize the Flask app
app = Flask(__name__)
CORS(app, resources={r"/api/": {"origins": "*"}})  # Enable CORS for all origins

# --- MySQL Database Configuration ---
db_config = {
    'host': 'localhost',
    'user': 'STM',  # Your MySQL username
    'password': '123',  # Your MySQL password
    'database': 'STM'  # Your MySQL database name
}

# --- MySQL Connection ---
def get_db_connection():
    """Create and return a connection to the MySQL database."""
    try:
        conn = mysql.connector.connect(**db_config)
        print("Connection established successfully.")
        return conn
    except mysql.connector.Error as e:
        print(f"[ERROR] MySQL connection error: {e}")
        return None

# --- Image Handling Functions ---
def store_image_with_description(image_data, description, name, relation):
    """Store an image with its description and additional details in the MySQL database."""
    try:
        # Decode the image from base64
        image_binary = base64.b64decode(image_data)
        # Create a filename using the description
        filename = f"{description.replace(' ', '_')}.jpg"

        # Insert image data into the database
        conn = get_db_connection()
        if not conn:
            return {"error": "Failed to connect to the database."}

        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO images (description, image_data, filename, name, relation)
            VALUES (%s, %s, %s, %s, %s)
        """, (description, image_binary, filename, name, relation))
        conn.commit()
        cursor.close()
        conn.close()

        print(f"[INFO] Image '{description}' stored successfully.")
        return {"message": "Image stored successfully."}
    except Exception as e:
        print(f"[ERROR] Error storing image: {e}")
        return {"error": "Failed to store image."}

def match_image_base64(image_data):
    """Match uploaded image with stored images using base64 comparison."""
    try:
        conn = get_db_connection()
        if not conn:
            return None

        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM images")
        images = cursor.fetchall()

        for image in images:
            if image['image_data'] == base64.b64decode(image_data):
                print("[INFO] Found matching image.")
                return image
        return None  # No match found
    except Exception as e:
        print(f"[ERROR] Error matching image: {e}")
        return None

def match_image_base64(image_data):
    """Match uploaded image with stored images using base64 comparison."""
    try:
        conn = get_db_connection()
        if not conn:
            return None

        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT * FROM images")
        images = cursor.fetchall()

        for image in images:
            if image['image_data'] == base64.b64decode(image_data):
                print("[INFO] Found matching image.")
                # Return only the name, relation, and description of the matching image
                return {
                    'name': image['name'],
                    'relation': image['relation'],
                    'description': image['description']
                }
        return None  # No match found
    except Exception as e:
        print(f"[ERROR] Error matching image: {e}")
        return None


# --- Task Handling Functions ---
def store_task(task):
    """Store a new task in MySQL with a timestamp."""
    try:
        print(f"[INFO] Storing task: {task}")  # Print incoming task data
        conn = get_db_connection()
        if not conn:
            return {"error": "Failed to connect to the database."}

        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO tasks (task, created_at)
            VALUES (%s, %s)
        """, (task, datetime.utcnow()))
        conn.commit()
        cursor.close()
        conn.close()

        print(f"[INFO] Task '{task}' added successfully.")
    except Exception as e:
        print(f"[ERROR] Error adding task: {e}")

def get_schedules():
    """Retrieve all scheduled tasks from MySQL."""
    try:
        conn = get_db_connection()
        if not conn:
            return []

        cursor = conn.cursor(dictionary=True)
        cursor.execute("SELECT task FROM tasks")
        tasks = cursor.fetchall()
        cursor.close()
        conn.close()

        return [task['task'] for task in tasks]
    except Exception as e:
        print(f"[ERROR] Error fetching schedules: {e}")
        return []

def delete_task(task_name):
    """Delete a task from MySQL based on its name."""
    try:
        conn = get_db_connection()
        if not conn:
            return False

        cursor = conn.cursor()
        cursor.execute("DELETE FROM tasks WHERE task = %s", (task_name,))
        conn.commit()
        cursor.close()
        conn.close()

        print(f"[INFO] Task '{task_name}' deleted successfully.")
        return True
    except Exception as e:
        print(f"[ERROR] Error deleting task: {e}")
        return False

def delete_old_tasks():
    """Automatically delete tasks older than 7 days."""
    try:
        conn = get_db_connection()
        if not conn:
            return

        cursor = conn.cursor()
        seven_days_ago = datetime.utcnow() - timedelta(days=7)
        cursor.execute("DELETE FROM tasks WHERE created_at < %s", (seven_days_ago,))
        conn.commit()
        cursor.close()
        conn.close()
        print("[INFO] Deleted old tasks.")
    except Exception as e:
        print(f"[ERROR] Error deleting old tasks: {e}")

def find_intent(user_input, tasks):
    """Use TF-IDF and cosine similarity to match user input with tasks."""
    vectorizer = TfidfVectorizer()
    all_texts = [user_input] + tasks  # Combine input with tasks
    tfidf_matrix = vectorizer.fit_transform(all_texts)  # Create TF-IDF matrix
    similarities = cosine_similarity(tfidf_matrix[0:1], tfidf_matrix[1:]).flatten()
    best_match_index = similarities.argmax()  # Get the most similar task

    if similarities[best_match_index] > 0.1:
        return tasks[best_match_index]  # Return the matched task
    else:
        return "I couldn't find anything related to your request."

# --- API Endpoints ---
@app.route('/api/store-image', methods=['POST'])
def store_image_endpoint():
    """API endpoint to store an image with a description and additional details."""
    data = request.get_json()
    print(f"[INFO] Received data: {data}")  # Print incoming data
    image_data = data.get('image')
    description = data.get('description')
    name = data.get('name')
    relation = data.get('relation')

    if not image_data or not description or not name or not relation:
        return jsonify({"error": "Image, description, name, and relation are required."}), 400

    result = store_image_with_description(image_data, description, name, relation)
    return jsonify(result), 200

@app.route('/api/match-image', methods=['POST'])
def match_image_endpoint():
    """API endpoint to match an uploaded image with stored images."""
    data = request.get_json()
    print(f"[INFO] Received data: {data}")  # Print incoming data
    image_data = data.get('image')

    if not image_data:
        return jsonify({"error": "Image data is required."}), 400

    match = match_image_base64(image_data)
    if match:
        return jsonify({"message": "Matching image found.", "data": match}), 200
    
    return jsonify({"response": "No matching image found."}), 404


@app.route('/api/process-input', methods=['POST'])
def process_input():
    """API endpoint to process user input and handle tasks."""
    data = request.get_json()
    print(f"[INFO] Received data: {data}")  # Print incoming data
    user_input = data.get('text', '')  # 'text' field now matches the Flutter request

    if "completed the task" in user_input.lower():
        task_name = user_input.lower().replace("i completed the task", "").strip()
        if delete_task(task_name):
            return jsonify({"response": f"Task '{task_name}' has been deleted."}), 200
        return jsonify({"response": f"No matching task found for '{task_name}'."}), 404

    tasks = get_schedules()
    if not tasks:
        return jsonify({"response": "You don't have any scheduled tasks."}), 200

    response = find_intent(user_input, tasks)
    return jsonify({"response": response, "tasks": tasks}), 200

@app.route('/api/store-task', methods=['POST'])
def store_task_endpoint():
    """API endpoint to store a new task."""
    data = request.get_json()
    print(f"[INFO] Received data: {data}")  # Print incoming data
    task = data.get('message')

    if not task:
        return jsonify({"error": "Task is required."}), 400

    store_task(task)
    return jsonify({"message": "Task stored successfully."}), 200

# --- Scheduler Setup ---
scheduler = BackgroundScheduler()
scheduler.add_job(delete_old_tasks, 'interval', days=1)
scheduler.start()

if __name__ == '__main__':
    app.run(debug=True, host="0.0.0.0", port=5000)
