-- ============================================
-- 1. Database and Extension Setup
-- ============================================

-- Note: Creating a database requires superuser privileges.
-- Execute the following commands in a superuser session.

-- Connect to the default 'postgres' database
\c postgres

-- Create the database
CREATE DATABASE vector_store_dev;

-- Connect to the newly created database
\c vector_store_dev

-- Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- ============================================
-- 2. Table Creation for Each Embedding Model
-- ============================================

-- 2.1. CLIP Embeddings (512 dimensions)
CREATE TABLE documents_clip (
                                id SERIAL PRIMARY KEY,
                                content TEXT NOT NULL,
                                embedding VECTOR(512),  -- CLIP's embedding dimension
                                source VARCHAR(50) DEFAULT 'CLIP',
                                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                additional_info JSONB      -- Optional metadata
);

-- 2.2. Nomic Embeddings - Text (768 dimensions)
CREATE TABLE documents_nomic_text (
                                      id SERIAL PRIMARY KEY,
                                      content TEXT NOT NULL,
                                      embedding VECTOR(768),  -- Nomic-Embed-Text-v1.5's embedding dimension
                                      source VARCHAR(50) DEFAULT 'nomic-embed-text-v1.5',
                                      timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                      additional_info JSONB      -- Optional metadata
);

-- 2.3. Nomic Embeddings - Vision (768 dimensions)
CREATE TABLE documents_nomic_vision (
                                        id SERIAL PRIMARY KEY,
                                        content TEXT NOT NULL,
                                        embedding VECTOR(768),  -- Nomic-Embed-Vision-v1.5's embedding dimension
                                        source VARCHAR(50) DEFAULT 'nomic-embed-vision-v1.5',
                                        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                        additional_info JSONB      -- Optional metadata
);

-- 2.4. OpenAI Embeddings (1536 dimensions)
CREATE TABLE documents_openai (
                                  id SERIAL PRIMARY KEY,
                                  content TEXT NOT NULL,
                                  embedding VECTOR(1536),  -- OpenAI's embedding dimension
                                  source VARCHAR(50) DEFAULT 'OpenAI',
                                  timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                                  additional_info JSONB      -- Optional metadata
);

-- ============================================
-- 3. Sample Data Insertion into Each Table
-- ============================================

-- Note: Replace the placeholder vectors with actual embedding values.

-- 3.1. Insert sample data into 'documents_clip'
INSERT INTO documents_clip (content, embedding, additional_info)
VALUES
    ('Sample CLIP text 1', '[0.1, 0.2, 0.3, /* ... up to 512 dimensions */]'::vector, '{"category": "example_clip"}'),
    ('Sample CLIP text 2', '[0.2, 0.3, 0.4, /* ... up to 512 dimensions */]'::vector, '{"category": "example_clip"}');

-- 3.2. Insert sample data into 'documents_nomic_text'
INSERT INTO documents_nomic_text (content, embedding, additional_info)
VALUES
    ('Sample Nomic Text 1', '[0.1, 0.2, 0.3, /* ... up to 768 dimensions */]'::vector, '{"category": "example_nomic_text"}'),
    ('Sample Nomic Text 2', '[0.2, 0.3, 0.4, /* ... up to 768 dimensions */]'::vector, '{"category": "example_nomic_text"}');

-- 3.3. Insert sample data into 'documents_nomic_vision'
INSERT INTO documents_nomic_vision (content, embedding, additional_info)
VALUES
    ('Sample Nomic Vision 1', '[0.1, 0.2, 0.3, /* ... up to 768 dimensions */]'::vector, '{"category": "example_nomic_vision"}'),
    ('Sample Nomic Vision 2', '[0.2, 0.3, 0.4, /* ... up to 768 dimensions */]'::vector, '{"category": "example_nomic_vision"}');

-- 3.4. Insert sample data into 'documents_openai'
INSERT INTO documents_openai (content, embedding, additional_info)
VALUES
    ('Sample OpenAI Text 1', '[0.1, 0.2, 0.3, /* ... up to 1536 dimensions */]'::vector, '{"category": "example_openai"}'),
    ('Sample OpenAI Text 2', '[0.2, 0.3, 0.4, /* ... up to 1536 dimensions */]'::vector, '{"category": "example_openai"}');

-- ============================================
-- 4. Index Creation for Efficient Searches
-- ============================================

-- 4.1. IVFFLAT Index for Each Table

-- 4.1.1. IVFFLAT Index for 'documents_clip' using Cosine Similarity
CREATE INDEX documents_clip_ivfflat_cosine
    ON documents_clip
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- 4.1.2. IVFFLAT Index for 'documents_nomic_text' using Cosine Similarity
CREATE INDEX documents_nomic_text_ivfflat_cosine
    ON documents_nomic_text
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- 4.1.3. IVFFLAT Index for 'documents_nomic_vision' using Cosine Similarity
CREATE INDEX documents_nomic_vision_ivfflat_cosine
    ON documents_nomic_vision
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- 4.1.4. IVFFLAT Index for 'documents_openai' using Cosine Similarity
CREATE INDEX documents_openai_ivfflat_cosine
    ON documents_openai
    USING ivfflat (embedding vector_cosine_ops)
    WITH (lists = 100);

-- 4.2. HNSW Index for Each Table

-- 4.2.1. HNSW Index for 'documents_clip' using Cosine Similarity
CREATE INDEX documents_clip_hnsw_cosine
    ON documents_clip
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 4.2.2. HNSW Index for 'documents_nomic_text' using Cosine Similarity
CREATE INDEX documents_nomic_text_hnsw_cosine
    ON documents_nomic_text
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 4.2.3. HNSW Index for 'documents_nomic_vision' using Cosine Similarity
CREATE INDEX documents_nomic_vision_hnsw_cosine
    ON documents_nomic_vision
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- 4.2.4. HNSW Index for 'documents_openai' using Cosine Similarity
CREATE INDEX documents_openai_hnsw_cosine
    ON documents_openai
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- ============================================
-- 5. Function Definitions for Similarity Searches
-- ============================================

-- Note: Separate functions are defined for each embedding model/table to handle different search operations.

-- 5.1. K-Nearest Neighbors (KNN) Search Functions

-- 5.1.1. KNN Search for CLIP (512 dimensions)
CREATE OR REPLACE FUNCTION knn_search_clip(
    query_embedding VECTOR(512),
    k INTEGER
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_clip
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM knn_search_clip('[0.1, 0.2, 0.3, /* ... up to 512 dimensions */]'::vector, 5);

-- 5.1.2. KNN Search for Nomic-Embed-Text-v1.5 (768 dimensions)
CREATE OR REPLACE FUNCTION knn_search_nomic_text(
    query_embedding VECTOR(768),
    k INTEGER
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_nomic_text
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM knn_search_nomic_text('[0.1, 0.2, 0.3, /* ... up to 768 dimensions */]'::vector, 5);

-- 5.1.3. KNN Search for Nomic-Embed-Vision-v1.5 (768 dimensions)
CREATE OR REPLACE FUNCTION knn_search_nomic_vision(
    query_embedding VECTOR(768),
    k INTEGER
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_nomic_vision
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM knn_search_nomic_vision('[0.1, 0.2, 0.3, /* ... up to 768 dimensions */]'::vector, 5);

-- 5.1.4. KNN Search for OpenAI (1536 dimensions)
CREATE OR REPLACE FUNCTION knn_search_openai(
    query_embedding VECTOR(1536),
    k INTEGER
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_openai
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM knn_search_openai('[0.1, 0.2, 0.3, /* ... up to 1536 dimensions */]'::vector, 5);

-- 5.2. Batch KNN Search Functions

-- 5.2.1. Batch KNN Search for CLIP
CREATE OR REPLACE FUNCTION batch_knn_search_clip(
    query_embeddings VECTOR(512)[],
    k INTEGER
)
    RETURNS TABLE(query_index INT, id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    q.query_index,
    d.id,
    d.content,
    d.embedding <-> q.embedding AS distance
FROM
    unnest(query_embeddings) WITH ORDINALITY AS q(embedding, query_index)
        CROSS JOIN LATERAL (
        SELECT id, content, embedding
        FROM documents_clip
        ORDER BY embedding <-> q.embedding
            LIMIT k
    ) d
ORDER BY q.query_index, distance;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM batch_knn_search_clip(ARRAY['[0.1, 0.2, 0.3, /* ... */]'::vector, '[0.4, 0.5, 0.6, /* ... */]'::vector], 3);

-- 5.2.2. Batch KNN Search for Nomic-Embed-Text-v1.5
CREATE OR REPLACE FUNCTION batch_knn_search_nomic_text(
    query_embeddings VECTOR(768)[],
    k INTEGER
)
    RETURNS TABLE(query_index INT, id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    q.query_index,
    d.id,
    d.content,
    d.embedding <-> q.embedding AS distance
FROM
    unnest(query_embeddings) WITH ORDINALITY AS q(embedding, query_index)
        CROSS JOIN LATERAL (
        SELECT id, content, embedding
        FROM documents_nomic_text
        ORDER BY embedding <-> q.embedding
            LIMIT k
    ) d
ORDER BY q.query_index, distance;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM batch_knn_search_nomic_text(ARRAY['[0.1, 0.2, 0.3, /* ... */]'::vector, '[0.4, 0.5, 0.6, /* ... */]'::vector], 3);

-- 5.2.3. Batch KNN Search for Nomic-Embed-Vision-v1.5
CREATE OR REPLACE FUNCTION batch_knn_search_nomic_vision(
    query_embeddings VECTOR(768)[],
    k INTEGER
)
    RETURNS TABLE(query_index INT, id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    q.query_index,
    d.id,
    d.content,
    d.embedding <-> q.embedding AS distance
FROM
    unnest(query_embeddings) WITH ORDINALITY AS q(embedding, query_index)
        CROSS JOIN LATERAL (
        SELECT id, content, embedding
        FROM documents_nomic_vision
        ORDER BY embedding <-> q.embedding
            LIMIT k
    ) d
ORDER BY q.query_index, distance;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM batch_knn_search_nomic_vision(ARRAY['[0.1, 0.2, 0.3, /* ... */]'::vector, '[0.4, 0.5, 0.6, /* ... */]'::vector], 3);

-- 5.2.4. Batch KNN Search for OpenAI
CREATE OR REPLACE FUNCTION batch_knn_search_openai(
    query_embeddings VECTOR(1536)[],
    k INTEGER
)
    RETURNS TABLE(query_index INT, id INT, content TEXT, distance FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    q.query_index,
    d.id,
    d.content,
    d.embedding <-> q.embedding AS distance
FROM
    unnest(query_embeddings) WITH ORDINALITY AS q(embedding, query_index)
        CROSS JOIN LATERAL (
        SELECT id, content, embedding
        FROM documents_openai
        ORDER BY embedding <-> q.embedding
            LIMIT k
    ) d
ORDER BY q.query_index, distance;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM batch_knn_search_openai(ARRAY['[0.1, 0.2, 0.3, /* ... */]'::vector, '[0.4, 0.5, 0.6, /* ... */]'::vector], 3);

-- 5.3. Approximate Nearest Neighbors (ANN) Search Functions Using HNSW

-- 5.3.1. ANN Search for CLIP
CREATE OR REPLACE FUNCTION ann_search_clip(
    query_embedding VECTOR(512),
    k INTEGER,
    probes INTEGER DEFAULT 10
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
    -- Set the number of probes for the search to balance between speed and accuracy
EXECUTE 'SET LOCAL hnsw.ef_search = ' || probes;

RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_clip
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM ann_search_clip('[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 10);

-- 5.3.2. ANN Search for Nomic-Embed-Text-v1.5
CREATE OR REPLACE FUNCTION ann_search_nomic_text(
    query_embedding VECTOR(768),
    k INTEGER,
    probes INTEGER DEFAULT 10
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
    -- Set the number of probes for the search to balance between speed and accuracy
EXECUTE 'SET LOCAL hnsw.ef_search = ' || probes;

RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_nomic_text
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM ann_search_nomic_text('[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 10);

-- 5.3.3. ANN Search for Nomic-Embed-Vision-v1.5
CREATE OR REPLACE FUNCTION ann_search_nomic_vision(
    query_embedding VECTOR(768),
    k INTEGER,
    probes INTEGER DEFAULT 10
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
    -- Set the number of probes for the search to balance between speed and accuracy
EXECUTE 'SET LOCAL hnsw.ef_search = ' || probes;

RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_nomic_vision
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM ann_search_nomic_vision('[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 10);

-- 5.3.4. ANN Search for OpenAI
CREATE OR REPLACE FUNCTION ann_search_openai(
    query_embedding VECTOR(1536),
    k INTEGER,
    probes INTEGER DEFAULT 10
)
    RETURNS TABLE(id INT, content TEXT, distance FLOAT) AS $$
BEGIN
    -- Set the number of probes for the search to balance between speed and accuracy
EXECUTE 'SET LOCAL hnsw.ef_search = ' || probes;

RETURN QUERY
SELECT
    id,
    content,
    embedding <-> query_embedding AS distance
FROM documents_openai
ORDER BY embedding <-> query_embedding
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM ann_search_openai('[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 10);

-- 5.4. Hybrid Search Combining Vector Similarity and Text Matching

-- 5.4.1. Hybrid Search for CLIP
CREATE OR REPLACE FUNCTION hybrid_search_clip(
    query_text TEXT,
    query_embedding VECTOR(512),
    k INTEGER,
    vector_weight FLOAT,
    text_weight FLOAT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT, text_rank FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity,
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) AS text_rank
FROM documents_clip d
WHERE to_tsvector('english', d.content) @@ plainto_tsquery('english', query_text)
ORDER BY
    (1 - (d.embedding <-> query_embedding)) * vector_weight +
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) * text_weight
        DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM hybrid_search_clip('sample query', '[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 0.7, 0.3);

-- 5.4.2. Hybrid Search for Nomic-Embed-Text-v1.5
CREATE OR REPLACE FUNCTION hybrid_search_nomic_text(
    query_text TEXT,
    query_embedding VECTOR(768),
    k INTEGER,
    vector_weight FLOAT,
    text_weight FLOAT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT, text_rank FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity,
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) AS text_rank
FROM documents_nomic_text d
WHERE to_tsvector('english', d.content) @@ plainto_tsquery('english', query_text)
ORDER BY
    (1 - (d.embedding <-> query_embedding)) * vector_weight +
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) * text_weight
        DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM hybrid_search_nomic_text('sample query', '[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 0.7, 0.3);

-- 5.4.3. Hybrid Search for Nomic-Embed-Vision-v1.5
CREATE OR REPLACE FUNCTION hybrid_search_nomic_vision(
    query_text TEXT,
    query_embedding VECTOR(768),
    k INTEGER,
    vector_weight FLOAT,
    text_weight FLOAT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT, text_rank FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity,
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) AS text_rank
FROM documents_nomic_vision d
WHERE to_tsvector('english', d.content) @@ plainto_tsquery('english', query_text)
ORDER BY
    (1 - (d.embedding <-> query_embedding)) * vector_weight +
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) * text_weight
        DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM hybrid_search_nomic_vision('sample query', '[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 0.7, 0.3);

-- 5.4.4. Hybrid Search for OpenAI
CREATE OR REPLACE FUNCTION hybrid_search_openai(
    query_text TEXT,
    query_embedding VECTOR(1536),
    k INTEGER,
    vector_weight FLOAT,
    text_weight FLOAT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT, text_rank FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity,
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) AS text_rank
FROM documents_openai d
WHERE to_tsvector('english', d.content) @@ plainto_tsquery('english', query_text)
ORDER BY
    (1 - (d.embedding <-> query_embedding)) * vector_weight +
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) * text_weight
        DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM hybrid_search_openai('sample query', '[0.1, 0.2, 0.3, /* ... */]'::vector, 5, 0.7, 0.3);

-- 5.5. Match Documents Function

-- 5.5.1. Match Documents for CLIP
CREATE OR REPLACE FUNCTION match_documents_clip(
    query_embedding VECTOR(512),
    match_threshold FLOAT,
    match_count INT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity
FROM documents_clip d
WHERE 1 - (d.embedding <-> query_embedding) > match_threshold
ORDER BY d.embedding <-> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM match_documents_clip('[0.2, 0.3, 0.4, /* ... */]'::vector, 0.7, 10);

-- 5.5.2. Match Documents for Nomic-Embed-Text-v1.5
CREATE OR REPLACE FUNCTION match_documents_nomic_text(
    query_embedding VECTOR(768),
    match_threshold FLOAT,
    match_count INT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity
FROM documents_nomic_text d
WHERE 1 - (d.embedding <-> query_embedding) > match_threshold
ORDER BY d.embedding <-> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM match_documents_nomic_text('[0.2, 0.3, 0.4, /* ... */]'::vector, 0.7, 10);

-- 5.5.3. Match Documents for Nomic-Embed-Vision-v1.5
CREATE OR REPLACE FUNCTION match_documents_nomic_vision(
    query_embedding VECTOR(768),
    match_threshold FLOAT,
    match_count INT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity
FROM documents_nomic_vision d
WHERE 1 - (d.embedding <-> query_embedding) > match_threshold
ORDER BY d.embedding <-> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM match_documents_nomic_vision('[0.2, 0.3, 0.4, /* ... */]'::vector, 0.7, 10);

-- 5.5.4. Match Documents for OpenAI
CREATE OR REPLACE FUNCTION match_documents_openai(
    query_embedding VECTOR(1536),
    match_threshold FLOAT,
    match_count INT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity
FROM documents_openai d
WHERE 1 - (d.embedding <-> query_embedding) > match_threshold
ORDER BY d.embedding <-> query_embedding
    LIMIT match_count;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM match_documents_openai('[0.2, 0.3, 0.4, /* ... */]'::vector, 0.7, 10);

-- ============================================
-- 6. Vector Operations and Advanced Features
-- ============================================

-- 6.1. Storing Vectors

-- 6.1.1. Create a generic items table with a vector column (Optional)
CREATE TABLE items_generic (
                               id BIGSERIAL PRIMARY KEY,
                               embedding VECTOR(1536),  -- Adjust dimension as needed
                               category_id INT,
                               content TEXT,
                               textsearch TSVECTOR GENERATED ALWAYS AS (to_tsvector('english', content)) STORED
);

-- 6.1.2. Adding a vector column to an existing table (Example)
-- ALTER TABLE items_generic ADD COLUMN embedding VECTOR(1536);

-- 6.1.3. Inserting vectors individually
INSERT INTO items_generic (embedding, category_id, content) VALUES
                                                                ('[1,2,3, /* ... up to 1536 dimensions */]'::vector, 123, 'Example content 1'),
                                                                ('[4,5,6, /* ... up to 1536 dimensions */]'::vector, 123, 'Example content 2');

-- 6.1.4. Bulk loading vectors using COPY
-- Prepare a binary file with vectors and use the following command:
-- COPY items_generic (embedding) FROM '/path/to/vectors.bin' WITH (FORMAT BINARY);

-- 6.1.5. Upserting vectors
INSERT INTO items_generic (id, embedding, category_id, content)
VALUES (1, '[1,2,3, /* ... */]'::vector, 123, 'Updated content 1'),
       (2, '[4,5,6, /* ... */]'::vector, 123, 'Updated content 2')
    ON CONFLICT (id) DO UPDATE
                            SET embedding = EXCLUDED.embedding,
                            category_id = EXCLUDED.category_id,
                            content = EXCLUDED.content;

-- 6.1.6. Updating vectors
UPDATE items_generic SET embedding = '[1,2,3, /* ... */]'::vector WHERE id = 1;

-- 6.1.7. Deleting vectors
DELETE FROM items_generic WHERE id = 1;

-- ============================================
-- 7. Indexing Subvectors and Advanced Types
-- ============================================

-- 7.1. Half-Precision Vectors (halfvec) - up to 4,000 dimensions
CREATE TABLE items_halfvec (
                               id SERIAL PRIMARY KEY,
                               embedding HALFVEC(512)  -- Example for 512 dimensions
);

-- 7.1.1. Indexing halfvec using HNSW with L2 distance
CREATE INDEX items_halfvec_hnsw_l2
    ON items_halfvec
    USING hnsw ((embedding::halfvec(512)) halfvec_l2_ops)
    WITH (m = 16, ef_construction = 64);

-- 7.2. Binary Vectors (bit) - up to 64,000 dimensions
CREATE TABLE items_binary (
                              id SERIAL PRIMARY KEY,
                              embedding BIT(64)  -- Example for 64 dimensions
);

-- 7.2.1. Indexing binary vectors using Hamming distance
CREATE INDEX items_binary_hamming
    ON items_binary
    USING hnsw (embedding bit_hamming_ops);

-- 7.3. Sparse Vectors (sparsevec) - up to 1,000 non-zero elements
CREATE TABLE items_sparsevec (
                                 id SERIAL PRIMARY KEY,
                                 embedding SPARSEVEC(1000)  -- Example for 1000 non-zero elements
);

-- 7.3.1. Inserting sparse vectors
INSERT INTO items_sparsevec (embedding) VALUES
    ('{1:1,3:2,5:3}/5', '{2:4,4:5,6:6}/6');

-- 7.3.2. Indexing sparse vectors using IVFFLAT with L2 distance
CREATE INDEX items_sparsevec_ivfflat_l2
    ON items_sparsevec
    USING ivfflat (embedding vector_l2_ops)
    WITH (lists = 100);

-- ============================================
-- 8. Security Enhancements
-- ============================================

-- 8.1. Create Read-Only Role
CREATE ROLE readonly;
GRANT CONNECT ON DATABASE vector_store_dev TO readonly;
GRANT USAGE ON SCHEMA public TO readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO readonly;

-- 8.2. Create Uploader Role
CREATE ROLE uploader;
GRANT CONNECT ON DATABASE vector_store_dev TO uploader;
GRANT USAGE ON SCHEMA public TO uploader;
GRANT INSERT, UPDATE ON documents_clip, documents_nomic_text, documents_nomic_vision, documents_openai, items_generic, items_halfvec, items_binary, items_sparsevec TO uploader;

-- Optional: Grant usage on specific functions if necessary
-- GRANT EXECUTE ON FUNCTION knn_search_clip(VECTOR(512), INTEGER) TO uploader;
-- Repeat for other functions as needed

-- ============================================
-- 9. Monitoring and Optimization Tips
-- ============================================

-- 9.1. Index Build Optimization

-- Increase maintenance_work_mem for faster index builds
SET maintenance_work_mem = '8GB';

-- Increase the number of parallel workers for faster index creation (PostgreSQL 14+)
SET max_parallel_maintenance_workers = 7; -- Plus leader

-- For a large number of workers, also increase max_parallel_workers
SET max_parallel_workers = 16; -- Adjust based on your server's CPU cores

-- 9.2. Monitoring Indexing Progress (PostgreSQL 12+)
SELECT phase, ROUND(100.0 * blocks_done / NULLIF(blocks_total, 0), 1) AS percentage
FROM pg_stat_progress_create_index;

-- The phases for HNSW are:
-- initializing
-- loading tuples

-- The phases for IVFFlat are:
-- initializing
-- performing k-means
-- assigning tuples
-- loading tuples

-- 9.3. Query Optimization

-- Example: Use EXPLAIN ANALYZE to debug performance
EXPLAIN ANALYZE
SELECT * FROM documents_clip
ORDER BY embedding <-> '[3,1,2, /* ... up to 512 dimensions */]'::vector
LIMIT 5;

-- 9.4. Vacuuming

-- Reindex and vacuum to maintain performance
REINDEX INDEX documents_clip_hnsw_cosine;
VACUUM documents_clip;

-- Repeat for other indexes and tables as needed

-- 9.5. Performance Tuning

-- Use a tool like PgTune to set initial values for Postgres server parameters
-- Example:
-- SHOW config_file;
-- SHOW shared_buffers;
-- Adjust settings in the config file and restart PostgreSQL

-- ============================================
-- 10. Additional Advanced Features
-- ============================================

-- 10.1. Filtering with WHERE Clauses

-- Example: Get the nearest neighbors to a vector within a specific category
SELECT * FROM items_generic
WHERE category_id = 123
ORDER BY embedding <-> '[3,1,2]'::vector
LIMIT 5;

-- Create an index on category_id for exact search
CREATE INDEX items_generic_category_id_idx ON items_generic (category_id);

-- Or create a partial HNSW index for approximate search within a category
CREATE INDEX items_generic_hnsw_l2_category_123
    ON items_generic
    USING hnsw (embedding vector_l2_ops)
    WITH (m = 16, ef_construction = 64)
    WHERE category_id = 123;

-- 10.2. Hybrid Search Example with Text Matching

-- Combining full-text search with vector similarity

CREATE OR REPLACE FUNCTION hybrid_search_items_generic(
    query_text TEXT,
    query_embedding VECTOR(1536),
    k INTEGER,
    vector_weight FLOAT,
    text_weight FLOAT
)
    RETURNS TABLE(id INT, content TEXT, similarity FLOAT, text_rank FLOAT) AS $$
BEGIN
RETURN QUERY
SELECT
    d.id,
    d.content,
    1 - (d.embedding <-> query_embedding) AS similarity,
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) AS text_rank
FROM items_generic d
WHERE to_tsvector('english', d.content) @@ plainto_tsquery('english', query_text)
ORDER BY
    (1 - (d.embedding <-> query_embedding)) * vector_weight +
    ts_rank(to_tsvector('english', d.content), plainto_tsquery('english', query_text)) * text_weight
        DESC
    LIMIT k;
END;
$$ LANGUAGE plpgsql;

-- Usage Example:
-- SELECT * FROM hybrid_search_items_generic('search query', '[0.1, 0.2, 0.3, /* ... up to 1536 dimensions */]'::vector, 5, 0.7, 0.3);

-- 10.3. Indexing Subvectors

-- Create a subvector index for 'items_generic' (e.g., first 3 dimensions)
CREATE INDEX items_generic_subvector_idx
    ON items_generic
    USING hnsw ((subvector(embedding, 1, 3)::vector(3)) vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);

-- Query using the subvector
SELECT * FROM items_generic
ORDER BY subvector(embedding, 1, 3)::vector(3) <=> subvector('[1,2,3,4,5]'::vector, 1, 3)
LIMIT 5;

-- Re-rank by the full vector for better recall
SELECT * FROM (
                  SELECT * FROM items_generic
                  ORDER BY subvector(embedding, 1, 3)::vector(3) <=> subvector('[1,2,3,4,5]'::vector, 1, 3)
                  LIMIT 20
              ) sub
ORDER BY embedding <-> '[1,2,3,4,5]'::vector
LIMIT 5;

-- ============================================
-- 11. Frequently Asked Questions (FAQ)
-- ============================================

-- /*
-- FAQ:

-- 1. How many vectors can be stored in a single table?
--    - A non-partitioned table has a limit of 32 TB by default in PostgreSQL.
--    - A partitioned table can have thousands of partitions of that size.

-- 2. Is replication supported?
--    - Yes, pgvector uses the write-ahead log (WAL), which allows for replication and point-in-time recovery.

-- 3. What if I want to index vectors with more than 2,000 dimensions?
--    - Use half-precision indexing to index up to 4,000 dimensions or binary quantization to index up to 64,000 dimensions.
--    - Alternatively, consider dimensionality reduction techniques.

-- 4. Can I store vectors with different dimensions in the same column?
--    - Yes, using the generic `vector` type without specifying dimensions.
--    - Example:
--      CREATE TABLE embeddings (
--        model_id BIGINT,
--        item_id BIGINT,
--        embedding VECTOR,
--        PRIMARY KEY (model_id, item_id)
--      );

--      -- Create partial indexes based on model_id
--      CREATE INDEX embeddings_hnsw_vector_l2 ON embeddings USING hnsw ((embedding::vector(512)) vector_l2_ops) WHERE (model_id = 123);

--      -- Query with:
--      SELECT * FROM embeddings
--      WHERE model_id = 123
--      ORDER BY embedding::vector(512) <-> '[3,1,2]'::vector
--      LIMIT 5;

-- 5. Can I store vectors with more precision?
--    - Yes, use `double precision[]` or `numeric[]` types to store vectors with more precision.
--    - Example:
--      CREATE TABLE items_high_precision (
--        id BIGSERIAL PRIMARY KEY,
--        embedding DOUBLE PRECISION[]
--      );

--      INSERT INTO items_high_precision (embedding) VALUES ('{1,2,3}'::double precision[], '{4,5,6}'::double precision[]);

--      -- Add a check constraint for dimensions
--      ALTER TABLE items_high_precision ADD CHECK (vector_dims(embedding::vector) = 3);

--      -- Create expression index
--      CREATE INDEX items_high_precision_hnsw
--      ON items_high_precision
--      USING hnsw ((embedding::vector(3)) vector_l2_ops);

--      -- Query
--      SELECT * FROM items_high_precision
--      ORDER BY embedding::vector(3) <-> '[3,1,2]'::vector
--      LIMIT 5;

-- 6. Do indexes need to fit into memory?
--    - No, but like other index types, you’ll likely see better performance if they do.
--    - Check index size with:
--      SELECT pg_size_pretty(pg_relation_size('index_name'));
-- */

-- ============================================
-- 12. Script Execution Instructions
-- ============================================

-- To execute this script:

-- 1. Save the script to a file named 'setup_pgvector_extended.sql'.
-- 2. Open your terminal or command prompt.
-- 3. Execute the script using psql:
--    psql -U your_username -f setup_pgvector_extended.sql

-- Replace 'your_username' with your PostgreSQL username.
-- Ensure that the 'vector_store_dev' database is created before running the rest of the script.

-- Alternatively, you can run each section step-by-step in a PostgreSQL client like pgAdmin or DBeaver.

-- ============================================
-- 13. Conclusion
-- ============================================

-- ============================================
-- **Key Highlights:**
--
-- - **Modular Design:** Separate tables for each embedding model ensure clarity and maintainability.
-- - **Efficient Searches:** Utilizes both IVFFLAT and HNSW indexing for optimal performance based on your requirements.
-- - **Flexibility:** Provides specialized functions for KNN, batch KNN, ANN, hybrid searches, and document matching for each model.
-- - **Security:** Implements role-based access controls to safeguard data.
-- - **Advanced Features:** Supports various vector types, subvectors indexing, and hybrid search combining vector similarity with text search.
-- - **Scalability:** Designed to handle large datasets with optimized indexing and potential for further scaling.
--
-- **Next Steps:**
--
-- 1. **Populate the Database:** Insert actual embedding vectors generated by your models into their respective tables.
-- 2. **Integrate with Backend Services:** Ensure your application interacts correctly with the database, utilizing the defined functions for similarity searches.
-- 3. **Optimize and Monitor:** Continuously monitor performance and make necessary adjustments to indexing and configurations based on real-world usage.
-- 4. **Automate Deployments:** Use migration tools like Flyway or Liquibase to manage schema changes and deploy updates seamlessly across environments.
-- 5. **Leverage Advanced Features:** Utilize hybrid search, subvectors indexing, and different vector types to enhance your search capabilities.
-- 6. **Regular Maintenance:** Perform regular maintenance tasks such as vacuuming and reindexing to maintain optimal database performance.
