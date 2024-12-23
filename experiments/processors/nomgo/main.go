package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	_ "github.com/lib/pq"
)

const (
    PORT          = "8000"
    NOMIC_API_URL = "https://api-atlas.nomic.ai/v1/embedding/text"
    MAX_FILE_SIZE = 20 << 20 // 20MB
)

const (
    host     = "localhost"
    port     = 5432
    user     = "myuser"
    password = "mypassword"
    dbname   = "embeddings_db"
)

type NomicRequest struct {
    Texts            []string `json:"texts"`
    TaskType         string   `json:"task_type"`
    MaxTokensPerText int      `json:"max_tokens_per_text"`
    Dimensionality   int      `json:"dimensionality"`
}

type NomicResponse struct {
    Embeddings [][]float64 `json:"embeddings"`
}

type FileRecord struct {
    ID        int       `json:"id"`
    Filename  string    `json:"filename"`
    Size      int64     `json:"size"`
    CreatedAt time.Time `json:"created_at"`
}

type Response struct {
    ID        int64     `json:"id,omitempty"`
    Filename  string    `json:"filename,omitempty"`
    Embedding []float64 `json:"embedding,omitempty"`
    Error     string    `json:"error,omitempty"`
}

var db *sql.DB

func init() {
    log.Println("Initializing database connection...")

    psqlInfo := fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=disable",
        host, port, user, password, dbname)

    log.Printf("Attempting to connect to PostgreSQL at %s:%d", host, port)

    var err error
    db, err = sql.Open("postgres", psqlInfo)
    if err != nil {
        log.Fatalf("Error opening database connection: %v", err)
    }

    // Set connection pool settings
    db.SetMaxOpenConns(25)
    db.SetMaxIdleConns(5)
    db.SetConnMaxLifetime(5 * time.Minute)

    // Test the connection
    err = db.Ping()
    if err != nil {
        log.Fatalf("Error pinging database: %v", err)
    }

    log.Println("Successfully connected to database. Testing table creation...")

    // Create tables if they don't exist
    createTableSQL := `
    CREATE TABLE IF NOT EXISTS embeddings (
        id SERIAL PRIMARY KEY,
        filename TEXT NOT NULL,
        content TEXT NOT NULL,
        embedding JSONB NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );`

    _, err = db.Exec(createTableSQL)
    if err != nil {
        log.Fatalf("Error creating tables: %v", err)
    }

    // Test a simple query
    var count int
    err = db.QueryRow("SELECT COUNT(*) FROM embeddings").Scan(&count)
    if err != nil {
        log.Fatalf("Error querying embeddings table: %v", err)
    }

    log.Printf("Database initialization complete. Found %d existing records.", count)
}

func isTextFile(filename string) bool {
    ext := strings.ToLower(filepath.Ext(filename))
    supportedExts := map[string]bool{
        ".txt":  true,
        ".md":   true,
        ".text": true,
    }
    return supportedExts[ext]
}

func handleFileUpload(c *gin.Context) {
    file, err := c.FormFile("file")
    if err != nil {
        log.Printf("Error getting file from form: %v", err)
        c.JSON(http.StatusBadRequest, Response{Error: "Failed to get file from form"})
        return
    }

    log.Printf("Processing file: %s (size: %d bytes)", file.Filename, file.Size)

    if file.Size > MAX_FILE_SIZE {
        c.JSON(http.StatusBadRequest, Response{
            Error: fmt.Sprintf("File size exceeds maximum limit of %d MB", MAX_FILE_SIZE/(1<<20)),
        })
        return
    }

    if !isTextFile(file.Filename) {
        c.JSON(http.StatusBadRequest, Response{
            Error: fmt.Sprintf("Only .txt, .md files are supported. Got: %s", filepath.Ext(file.Filename)),
        })
        return
    }

    src, err := file.Open()
    if err != nil {
        log.Printf("Error opening file: %v", err)
        c.JSON(http.StatusInternalServerError, Response{
            Error: fmt.Sprintf("Failed to open file: %v", err),
        })
        return
    }
    defer src.Close()

    content, err := io.ReadAll(src)
    if err != nil {
        log.Printf("Error reading file: %v", err)
        c.JSON(http.StatusInternalServerError, Response{
            Error: fmt.Sprintf("Failed to read file: %v", err),
        })
        return
    }

    text := string(content)
    text = strings.TrimSpace(text)

    if text == "" {
        c.JSON(http.StatusBadRequest, Response{
            Error: "File is empty",
        })
        return
    }

    log.Printf("Successfully read file. Content length: %d characters", len(text))

    embedding, err := generateEmbedding(text)
    if err != nil {
        log.Printf("Error generating embedding: %v", err)
        c.JSON(http.StatusInternalServerError, Response{
            Error: fmt.Sprintf("Failed to generate embedding: %v", err),
        })
        return
    }

    // Save to database
    id, err := saveEmbedding(file.Filename, text, embedding)
    if err != nil {
        log.Printf("Error saving to database: %v", err)
        c.JSON(http.StatusInternalServerError, Response{
            Error: fmt.Sprintf("Failed to save embedding: %v", err),
        })
        return
    }

    log.Printf("Successfully processed file. ID: %d, Embedding length: %d", id, len(embedding))
    c.JSON(http.StatusOK, Response{
        ID:        id,
        Filename:  file.Filename,
        Embedding: embedding,
    })
}

func generateEmbedding(text string) ([]float64, error) {
    nomicToken := os.Getenv("NOMIC_API_KEY")
    if nomicToken == "" {
        return nil, fmt.Errorf("NOMIC_API_KEY environment variable not set")
    }

    maxLength := 32000
    if len(text) > maxLength {
        text = text[:maxLength]
    }

    requestBody := NomicRequest{
        Texts:            []string{text},
        TaskType:         "search_document",
        MaxTokensPerText: 8192,
        Dimensionality:   768,
    }

    jsonBody, err := json.Marshal(requestBody)
    if err != nil {
        return nil, fmt.Errorf("failed to marshal request: %v", err)
    }

    req, err := http.NewRequest("POST", NOMIC_API_URL, bytes.NewBuffer(jsonBody))
    if err != nil {
        return nil, fmt.Errorf("failed to create request: %v", err)
    }

    req.Header.Set("Content-Type", "application/json")
    req.Header.Set("Accept", "application/json")
    req.Header.Set("Authorization", "Bearer "+nomicToken)

    client := &http.Client{Timeout: time.Second * 30}

    resp, err := client.Do(req)
    if err != nil {
        return nil, fmt.Errorf("failed to send request: %v", err)
    }
    defer resp.Body.Close()

    bodyBytes, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil, fmt.Errorf("failed to read response body: %v", err)
    }

    if resp.StatusCode != http.StatusOK {
        log.Printf("API Error Response: %s", string(bodyBytes))
        return nil, fmt.Errorf("API request failed with status %d: %s", resp.StatusCode, string(bodyBytes))
    }

    var nomicResponse NomicResponse
    if err := json.Unmarshal(bodyBytes, &nomicResponse); err != nil {
        log.Printf("Failed to parse response: %s", string(bodyBytes))
        return nil, fmt.Errorf("failed to decode response: %v", err)
    }

    if len(nomicResponse.Embeddings) == 0 || len(nomicResponse.Embeddings[0]) == 0 {
        return nil, fmt.Errorf("no embeddings received from API")
    }

    return nomicResponse.Embeddings[0], nil
}

func saveEmbedding(filename, content string, embedding []float64) (int64, error) {
    embeddingJSON, err := json.Marshal(embedding)
    if err != nil {
        return 0, fmt.Errorf("failed to marshal embedding: %v", err)
    }

    var id int64
    err = db.QueryRow(`
        INSERT INTO embeddings (filename, content, embedding)
        VALUES ($1, $2, $3::jsonb)
        RETURNING id`,
        filename, content, string(embeddingJSON),
    ).Scan(&id)

    if err != nil {
        return 0, fmt.Errorf("failed to save to database: %v", err)
    }

    return id, nil
}

func handleGetFiles(c *gin.Context) {
    log.Println("Handling request to get files...")

    files := []FileRecord{}

    query := `
        SELECT id, filename, length(content) as size, created_at
        FROM embeddings
        ORDER BY created_at DESC
    `

    log.Printf("Executing query: %s", query)

    rows, err := db.Query(query)
    if err != nil {
        log.Printf("Database query failed: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Database query failed: %v", err)})
        return
    }
    defer rows.Close()

    for rows.Next() {
        var file FileRecord
        err := rows.Scan(&file.ID, &file.Filename, &file.Size, &file.CreatedAt)
        if err != nil {
            log.Printf("Row scan failed: %v", err)
            c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Row scan failed: %v", err)})
            return
        }
        files = append(files, file)
    }

    if err = rows.Err(); err != nil {
        log.Printf("Row iteration failed: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{"error": fmt.Sprintf("Row iteration failed: %v", err)})
        return
    }

    log.Printf("Successfully retrieved %d files", len(files))
    c.JSON(http.StatusOK, files)
}

func handleDatabaseHealth(c *gin.Context) {
    log.Println("Checking database health...")

    // Test basic connection
    err := db.Ping()
    if err != nil {
        log.Printf("Database ping failed: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{
            "status": "error",
            "error": "Database ping failed",
            "details": err.Error(),
        })
        return
    }

    // Get table information
    var tableExists bool
    err = db.QueryRow(`
        SELECT EXISTS (
            SELECT FROM information_schema.tables
            WHERE table_schema = 'public'
            AND table_name = 'embeddings'
        )
    `).Scan(&tableExists)

    if err != nil {
        log.Printf("Error checking table existence: %v", err)
        c.JSON(http.StatusInternalServerError, gin.H{
            "status": "error",
            "error": "Error checking table existence",
            "details": err.Error(),
        })
        return
    }

    // Get record count
    var recordCount int
    if tableExists {
        err = db.QueryRow("SELECT COUNT(*) FROM embeddings").Scan(&recordCount)
        if err != nil {
            log.Printf("Error counting records: %v", err)
            c.JSON(http.StatusInternalServerError, gin.H{
                "status": "error",
                "error": "Error counting records",
                "details": err.Error(),
            })
            return
        }
    }

    c.JSON(http.StatusOK, gin.H{
        "status": "healthy",
        "table_exists": tableExists,
        "record_count": recordCount,
        "connection": "active",
    })
}

func serveHomepage(c *gin.Context) {
    c.HTML(http.StatusOK, "vector_dropzone.html", gin.H{
        "title": "Vector Dropzone",
    })
}

func setupRouter() *gin.Engine {
    router := gin.New()
    router.Use(gin.Logger())
    router.Use(gin.Recovery())

    config := cors.DefaultConfig()
    config.AllowAllOrigins = true
    config.AllowMethods = []string{"GET", "POST", "OPTIONS"}
    config.AllowHeaders = []string{"Origin", "Content-Type", "Accept"}
    router.Use(cors.New(config))

    router.MaxMultipartMemory = MAX_FILE_SIZE
    router.LoadHTMLFiles("vector_dropzone.html")

    router.GET("/", serveHomepage)
    router.GET("/health", handleDatabaseHealth)
    router.POST("/generate-embedding", handleFileUpload)
    router.GET("/api/files", handleGetFiles)

    return router
}

func main() {
    defer db.Close()

    gin.SetMode(gin.ReleaseMode)
    router := setupRouter()

    log.Printf("Server starting on port %s...\n", PORT)
    if err := router.Run(":" + PORT); err != nil {
        log.Fatal("Failed to start server:", err)
    }
}
