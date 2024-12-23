import os
import psycopg2
from psycopg2 import sql
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from psycopg2.extras import execute_values, Json
from transformers import CLIPProcessor, CLIPModel
import torch
import time

# ============================
# Configuration Parameters
# ============================

# PostgreSQL server connection parameters
PG_HOST = 'localhost'
PG_PORT = '5432'
PG_USER = 'macadelic'       # Replace with your PostgreSQL username
PG_PASSWORD = 'password'    # Replace with your PostgreSQL password

# Target database and table
TARGET_DB = 'vector_store_dev'
TARGET_TABLE = 'documents_clip'

# List of texts to generate embeddings for
TEXTS = [
    "The quick brown fox jumps over the lazy dog.",
    "OpenAI develops powerful AI models.",
    "PostgreSQL is a robust open-source database system.",
    "Artificial Intelligence is transforming industries.",
    "Natural Language Processing enables machines to understand human language."
]

# ============================
# Helper Function for Timing
# ============================

def time_it(func):
    """
    Decorator to measure the execution time of functions.
    """
    def wrapper(*args, **kwargs):
        start_time = time.perf_counter()
        result = func(*args, **kwargs)
        end_time = time.perf_counter()
        elapsed = end_time - start_time
        print(f"Function '{func.__name__}' executed in {elapsed:.4f} seconds.")
        return result
    return wrapper

# ============================
# Initialize CLIP Model
# ============================

@time_it
def initialize_clip_model():
    """
    Initializes and returns the CLIP model and processor.
    """
    print("Loading CLIP model...")
    model = CLIPModel.from_pretrained("openai/clip-vit-base-patch32")
    processor = CLIPProcessor.from_pretrained("openai/clip-vit-base-patch32")
    return model, processor

# ============================
# Generate Embeddings
# ============================

@time_it
def generate_embeddings(model, processor, texts):
    """
    Generates embeddings for a list of texts using the CLIP model.

    Args:
        model: The CLIP model.
        processor: The CLIP processor.
        texts (list of str): The texts to generate embeddings for.

    Returns:
        list of list of float: The generated embeddings.
    """
    print("Generating embeddings...")
    inputs = processor(text=texts, return_tensors="pt", padding=True, truncation=True)

    with torch.no_grad():
        outputs = model.get_text_features(**inputs)

    # Normalize embeddings
    embeddings = outputs / outputs.norm(p=2, dim=-1, keepdim=True)

    # Convert to list of floats
    embeddings = embeddings.cpu().tolist()

    print(f"Generated embeddings for {len(texts)} texts.")
    return embeddings

# ============================
# Database Operations
# ============================

@time_it
def create_database_if_not_exists(conn, db_name):
    """
    Creates a PostgreSQL database if it does not exist.

    Args:
        conn: The psycopg2 connection object connected to the server.
        db_name (str): The name of the database to create.
    """
    cursor = conn.cursor()
    cursor.execute("SELECT 1 FROM pg_catalog.pg_database WHERE datname = %s;", (db_name,))
    exists = cursor.fetchone()
    if not exists:
        print(f"Database '{db_name}' does not exist. Creating...")
        cursor.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(db_name)))
        print(f"Database '{db_name}' created successfully.")
    else:
        print(f"Database '{db_name}' already exists.")
    cursor.close()

@time_it
def enable_pgvector_extension(conn):
    """
    Enables the pgvector extension if it is not already enabled.

    Args:
        conn: The psycopg2 connection object connected to the target database.
    """
    cursor = conn.cursor()
    cursor.execute("""
        SELECT EXISTS (
            SELECT FROM pg_extension
            WHERE extname = 'vector'
        );
    """)
    exists = cursor.fetchone()[0]
    if not exists:
        print("pgvector extension not found. Enabling...")
        cursor.execute("CREATE EXTENSION vector;")
        print("pgvector extension enabled.")
    else:
        print("pgvector extension is already enabled.")
    cursor.close()

@time_it
def create_documents_clip_table(conn):
    """
    Creates the documents_clip table if it does not exist.

    Args:
        conn: The psycopg2 connection object connected to the target database.
    """
    cursor = conn.cursor()
    # Check if table exists
    cursor.execute("""
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = %s
        );
    """, (TARGET_TABLE,))
    exists = cursor.fetchone()[0]
    if not exists:
        print(f"Table '{TARGET_TABLE}' does not exist. Creating...")
        cursor.execute(sql.SQL("""
            CREATE TABLE {table} (
                id SERIAL PRIMARY KEY,
                content TEXT NOT NULL,
                embedding VECTOR(512),  -- CLIP's embedding dimension
                source VARCHAR(50) DEFAULT 'CLIP',
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                additional_info JSONB      -- Optional metadata
            );
        """).format(table=sql.Identifier(TARGET_TABLE)))
        print(f"Table '{TARGET_TABLE}' created successfully.")
    else:
        print(f"Table '{TARGET_TABLE}' already exists.")
    cursor.close()

# ============================
# Insert Embeddings into PostgreSQL
# ============================

@time_it
def insert_embeddings(conn, texts, embeddings, additional_info_list=None):
    """
    Inserts texts and their embeddings into the documents_clip table.

    Args:
        conn: The psycopg2 connection object.
        texts (list of str): The texts.
        embeddings (list of list of float): The corresponding embeddings.
        additional_info_list (list of dict, optional): Additional metadata for each entry.
    """
    print("Inserting embeddings into the database...")
    cursor = conn.cursor()

    # Prepare the data for insertion
    data = []
    for idx, text in enumerate(texts):
        embedding = embeddings[idx]
        # Wrap the additional_info dict with Json
        additional_info = Json(additional_info_list[idx]) if additional_info_list else Json({})
        data.append((text, embedding, additional_info))

    # Define the SQL INSERT statement
    insert_query = sql.SQL("""
        INSERT INTO {table} (content, embedding, additional_info)
        VALUES %s
    """).format(table=sql.Identifier(TARGET_TABLE))

    # Use execute_values for efficient bulk insertion
    execute_values(
        cursor, insert_query, data,
        template="(%s, %s, %s)"
    )

    # Commit the transaction
    conn.commit()
    cursor.close()
    print("Embeddings inserted successfully.")

# ============================
# Main Function
# ============================

def main():
    total_start = time.perf_counter()

    # Initialize the CLIP model and processor
    model, processor = initialize_clip_model()

    # Generate embeddings for the texts
    embeddings = generate_embeddings(model, processor, TEXTS)

    # Optionally, define additional_info for each text
    additional_info_list = [
        {"category": "example_clip"},
        {"category": "example_clip"},
        {"category": "example_clip"},
        {"category": "example_clip"},
        {"category": "example_clip"}
    ]

    # Connect to the PostgreSQL server (default database 'postgres')
    print("Connecting to the PostgreSQL server...")
    try:
        conn_postgres = psycopg2.connect(
            host=PG_HOST,
            port=PG_PORT,
            dbname='postgres',
            user=PG_USER,
            password=PG_PASSWORD
        )
        conn_postgres.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)  # Required to CREATE DATABASE
    except Exception as e:
        print("Failed to connect to the PostgreSQL server.")
        print(e)
        return

    # Create the target database if it doesn't exist
    try:
        create_database_if_not_exists(conn_postgres, TARGET_DB)
    except Exception as e:
        print("Failed to create/check the target database.")
        print(e)
        conn_postgres.close()
        return
    finally:
        conn_postgres.close()

    # Connect to the target database
    print(f"Connecting to the '{TARGET_DB}' database...")
    try:
        conn_target = psycopg2.connect(
            host=PG_HOST,
            port=PG_PORT,
            dbname=TARGET_DB,
            user=PG_USER,
            password=PG_PASSWORD
        )
    except Exception as e:
        print(f"Failed to connect to the '{TARGET_DB}' database.")
        print(e)
        return

    # Enable pgvector extension
    try:
        enable_pgvector_extension(conn_target)
    except Exception as e:
        print("Failed to enable pgvector extension.")
        print(e)
        conn_target.close()
        return

    # Create the documents_clip table if it doesn't exist
    try:
        create_documents_clip_table(conn_target)
    except Exception as e:
        print("Failed to create/check the documents_clip table.")
        print(e)
        conn_target.close()
        return

    # Insert the embeddings into the database
    try:
        insert_embeddings(conn_target, TEXTS, embeddings, additional_info_list)
    except Exception as e:
        print("Failed to insert embeddings into the database.")
        print(e)
    finally:
        conn_target.close()
        print("Database connection closed.")

    total_end = time.perf_counter()
    total_elapsed = total_end - total_start
    print(f"Total script execution time: {total_elapsed:.4f} seconds.")

if __name__ == "__main__":
    main()
