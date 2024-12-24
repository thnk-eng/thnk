package main

import (
	"bufio"
	"fmt"
	"image"
	"image/color"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/disintegration/imaging"
	"github.com/spf13/cobra"
	_ "golang.org/x/image/webp"
	_ "image/jpeg"
	_ "image/png"
)

// Product represents a product with relevant details.
type Product struct {
	ID           int    `yaml:"id"`
	ExternalID   string `yaml:"external_id"`
	Name         string `yaml:"name"`
	ThumbnailURL string `yaml:"thumbnail_url"`
}

// Data holds a list of products parsed from YAML.
type Data struct {
	Products []Product `yaml:"data"`
}

var (
	downloadCount int64        // Use atomic operations for download count
	client        *http.Client // HTTP client for downloading images
)

// init initializes the HTTP client with optimized transport settings.
func init() {
	// Initialize the HTTP client with a timeout and transport settings for better performance.
	client = &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			MaxIdleConns:        200,               // Increased number of idle connections
			MaxIdleConnsPerHost: 200,               // Increased per-host idle connections
			IdleConnTimeout:     90 * time.Second,  // Idle connection timeout
			DisableKeepAlives:   false,             // Keep-alives enabled for connection reuse
		},
	}
}

func main() {
	// Define the root command.
	var rootCmd = &cobra.Command{
		Use:   "speedgo",
		Short: "Speedgo is a CLI tool for downloading, resizing, and normalizing images from YAML and TXT files.",
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

	// Define the 'yaml' subcommand.
	var yamlCmd = &cobra.Command{
		Use:   "yaml [input-dir] [output-dir]",
		Short: "Download, resize, and normalize images from YAML files in a directory",
		Args:  cobra.ExactArgs(2),
		Run: func(cmd *cobra.Command, args []string) {
			inputDir := args[0]
			outputDir := args[1]
			processYAML(inputDir, outputDir)
		},
	}

	// Define the 'txt' subcommand.
	var txtCmd = &cobra.Command{
		Use:   "txt [input-file] [output-dir]",
		Short: "Download, resize, and normalize images from a TXT file",
		Args:  cobra.ExactArgs(2),
		Run: func(cmd *cobra.Command, args []string) {
			inputFile := args[0]
			outputDir := args[1]
			processTXT(inputFile, outputDir)
		},
	}

	// Add subcommands to the root command.
	rootCmd.AddCommand(yamlCmd, txtCmd)

	// Execute the root command.
	if err := rootCmd.Execute(); err != nil {
		log.Fatalf("Error executing command: %v", err)
	}
}

// processYAML handles the 'yaml' subcommand logic.
func processYAML(inputDir, outputDir string) {
	startTime := time.Now()

	// Create the output directory if it doesn't exist.
	if err := os.MkdirAll(outputDir, os.ModePerm); err != nil {
		log.Fatalf("Failed to create output directory: %v", err)
	}

	// Determine the number of workers based on CPU cores.
	numWorkers := runtime.NumCPU() * 4

	// Create buffered channels to optimize throughput.
	imgChan := make(chan string, numWorkers*2)
	processChan := make(chan string, numWorkers*2)

	// Use WaitGroup to wait for all goroutines to finish.
	var wg sync.WaitGroup

	// Start downloader workers.
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go downloaderWorker(&wg, imgChan, processChan, outputDir)
	}

	// Start processor workers.
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go processorWorker(&wg, processChan)
	}

	// Walk through the input directory and process YAML files.
	err := filepath.Walk(inputDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			log.Printf("Error accessing path %s: %v", path, err)
			return nil // Continue walking
		}
		if !info.IsDir() && strings.ToLower(filepath.Ext(info.Name())) == ".yaml" {
			processYAMLFile(path, imgChan)
		}
		return nil
	})
	if err != nil {
		log.Fatalf("Failed to walk through input directory: %v", err)
	}

	// Close imgChan to signal downloader workers no more images.
	close(imgChan)

	// Wait for all workers to finish.
	wg.Wait()

	elapsed := time.Since(startTime)
	fmt.Printf("Successfully downloaded and processed %d images in %s\n", atomic.LoadInt64(&downloadCount), elapsed)
}

// processYAMLFile parses a YAML file and sends image URLs to imgChan.
func processYAMLFile(filePath string, imgChan chan<- string) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		log.Printf("Failed to read file %s: %v", filePath, err)
		return
	}

	var data Data
	if err := yaml.Unmarshal(content, &data); err != nil {
		log.Printf("Failed to unmarshal YAML file %s: %v", filePath, err)
		return
	}

	for _, product := range data.Products {
		if product.ThumbnailURL != "" {
			imgChan <- product.ThumbnailURL
		}
	}
}

// processTXT handles the 'txt' subcommand logic.
func processTXT(inputFile, outputDir string) {
	startTime := time.Now()

	// Create the output directory if it doesn't exist.
	if err := os.MkdirAll(outputDir, os.ModePerm); err != nil {
		log.Fatalf("Failed to create output directory: %v", err)
	}

	// Determine the number of workers based on CPU cores.
	numWorkers := runtime.NumCPU() * 4

	// Create buffered channels to optimize throughput.
	imgChan := make(chan string, numWorkers*2)
	processChan := make(chan string, numWorkers*2)

	// Use WaitGroup to wait for all goroutines to finish.
	var wg sync.WaitGroup

	// Start downloader workers.
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go downloaderWorker(&wg, imgChan, processChan, outputDir)
	}

	// Start processor workers.
	for i := 0; i < numWorkers; i++ {
		wg.Add(1)
		go processorWorker(&wg, processChan)
	}

	// Open the input TXT file.
	file, err := os.Open(inputFile)
	if err != nil {
		log.Fatalf("Failed to open input file: %v", err)
	}
	defer file.Close()

	// Use a buffered scanner for efficient reading.
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		url := strings.TrimSpace(scanner.Text())
		if url != "" {
			imgChan <- url
		}
	}

	if err := scanner.Err(); err != nil {
		log.Printf("Error reading input file: %v", err)
	}

	// Close imgChan to signal downloader workers no more images.
	close(imgChan)

	// Wait for all workers to finish.
	wg.Wait()

	elapsed := time.Since(startTime)
	fmt.Printf("Successfully downloaded and processed %d images in %s\n", atomic.LoadInt64(&downloadCount), elapsed)
}

// downloaderWorker downloads images from URLs received on imgChan and sends the file paths to processChan.
func downloaderWorker(wg *sync.WaitGroup, imgChan <-chan string, processChan chan<- string, outputDir string) {
	defer wg.Done()
	for url := range imgChan {
		filePath, err := downloadImage(url, outputDir)
		if err != nil {
			log.Printf("Error downloading %s: %v", url, err)
			continue
		}
		processChan <- filePath
	}
}

// processorWorker processes image files received on processChan.
func processorWorker(wg *sync.WaitGroup, processChan <-chan string) {
	defer wg.Done()
	for filePath := range processChan {
		if err := resizeAndNormalizeImage(filePath); err != nil {
			log.Printf("Error processing %s: %v", filePath, err)
			continue
		}
	}
}

// downloadImage downloads an image from the given URL and saves it to the output directory.
// It returns the file path of the downloaded image.
func downloadImage(url string, outputDir string) (string, error) {
	// Create a new request to allow for potential enhancements (e.g., headers, retries).
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return "", fmt.Errorf("failed to create HTTP request: %w", err)
	}

	// Perform the HTTP request.
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("failed to download image: %w", err)
	}
	defer resp.Body.Close()

	// Check for successful response.
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("failed to download image: %s", resp.Status)
	}

	// Extract filename from URL.
	fileName := extractFileName(url)
	if fileName == "" {
		fileName = fmt.Sprintf("image_%d", time.Now().UnixNano())
	} else {
		// Ensure the filename is safe.
		fileName = sanitizeFileName(fileName)
	}

	// Handle duplicate filenames by appending a counter.
	filePath := filepath.Join(outputDir, fileName)
	originalFilePath := filePath
	counter := 1
	for {
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			break
		}
		filePath = fmt.Sprintf("%s_%d%s", strings.TrimSuffix(originalFilePath, filepath.Ext(originalFilePath)), counter, filepath.Ext(originalFilePath))
		counter++
	}

	// Create the file with appropriate permissions.
	file, err := os.OpenFile(filePath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		return "", fmt.Errorf("failed to create file %s: %w", filePath, err)
	}
	defer file.Close()

	// Use a buffered writer for efficient writing.
	writer := bufio.NewWriter(file)
	if _, err := io.Copy(writer, resp.Body); err != nil {
		return "", fmt.Errorf("failed to save image %s: %w", filePath, err)
	}
	if err := writer.Flush(); err != nil {
		return "", fmt.Errorf("failed to flush data to file %s: %w", filePath, err)
	}

	// Atomically increment the download count.
	atomic.AddInt64(&downloadCount, 1)

	log.Printf("Successfully downloaded %s", filePath)
	return filePath, nil
}

// extractFileName extracts the file name from a URL.
func extractFileName(url string) string {
	parts := strings.Split(url, "/")
	if len(parts) == 0 {
		return ""
	}
	fileName := parts[len(parts)-1]
	fileName = strings.Split(fileName, "?")[0] // Remove query parameters.
	return fileName
}

// sanitizeFileName replaces invalid characters in a file name with underscores.
func sanitizeFileName(name string) string {
	// Replace any invalid characters with underscores.
	return strings.Map(func(r rune) rune {
		if strings.ContainsRune(`<>:"/\|?*`, r) || r < 32 {
			return '_'
		}
		return r
	}, name)
}

// resizeAndNormalizeImage resizes the image to half its original dimensions and normalizes it.
func resizeAndNormalizeImage(filePath string) error {
	// Open the image file using the imaging library.
	img, err := imaging.Open(filePath, imaging.AutoOrientation(true))
	if err != nil {
		return fmt.Errorf("failed to open image file: %w", err)
	}

	// Resize the image to half its original dimensions using a high-quality resampling filter.
	resizedImg := imaging.Resize(img, img.Bounds().Dx()/2, img.Bounds().Dy()/2, imaging.Lanczos)

	// Normalize the image.
	normalizedImg := normalizeImage(resizedImg)

	// Determine output file format.
	var outputFilePath string
	format := strings.ToLower(filepath.Ext(filePath))
	switch format {
	case ".jpeg", ".jpg":
		outputFilePath = filePath // Overwrite the original file.
	case ".png":
		outputFilePath = filePath // Overwrite the original file.
	case ".webp":
		// Convert WEBP to JPEG for normalization.
		outputFilePath = strings.TrimSuffix(filePath, filepath.Ext(filePath)) + ".jpg"
	default:
		return fmt.Errorf("unsupported image format: %s", format)
	}

	// Save the normalized image.
	switch format {
	case ".jpeg", ".jpg", ".webp":
		err = imaging.Save(normalizedImg, outputFilePath, imaging.JPEGQuality(90))
	case ".png":
		err = imaging.Save(normalizedImg, outputFilePath)
	}
	if err != nil {
		return fmt.Errorf("failed to save normalized image %s: %w", outputFilePath, err)
	}

	// If format was WEBP and converted to JPEG, delete the original WEBP file.
	if format == ".webp" {
		if err = os.Remove(filePath); err != nil {
			log.Printf("Warning: failed to delete original WEBP file %s: %v", filePath, err)
		}
	}

	// Log the successful processing.
	log.Printf("Successfully resized and normalized %s", outputFilePath)
	return nil
}

// normalizeImage standardizes the image's color channels globally.
func normalizeImage(img image.Image) image.Image {
	bounds := img.Bounds()
	normalized := imaging.Clone(img)

	var total, totalSq float64
	count := float64(bounds.Dx() * bounds.Dy() * 3) // 3 channels: R, G, B

	// Calculate the sum and sum of squares for all channels.
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, _ := img.At(x, y).RGBA()
			r8 := float64(r>>8) / 255.0
			g8 := float64(g>>8) / 255.0
			b8 := float64(b>>8) / 255.0

			total += r8 + g8 + b8
			totalSq += r8*r8 + g8*g8 + b8*b8
		}
	}

	// Calculate global mean and standard deviation.
	mean := total / count
	variance := (totalSq / count) - (mean * mean)
	stddev := math.Sqrt(variance)
	if stddev == 0 {
		stddev = 1 // Prevent division by zero
	}

	// Define scaling and offset.
	scaling := 0.5
	offset := 0.5

	// Normalize each pixel uniformly across all channels.
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, a := img.At(x, y).RGBA()
			r8 := (float64(r>>8)/255.0 - mean) / stddev
			g8 := (float64(g>>8)/255.0 - mean) / stddev
			b8 := (float64(b>>8)/255.0 - mean) / stddev

			// Apply scaling and offset
			rNorm := clamp(r8*scaling+offset, 0, 1) * 255.0
			gNorm := clamp(g8*scaling+offset, 0, 1) * 255.0
			bNorm := clamp(b8*scaling+offset, 0, 1) * 255.0

			normalized.Set(x, y, color.RGBA{
				R: uint8(rNorm),
				G: uint8(gNorm),
				B: uint8(bNorm),
				A: uint8(a >> 8),
			})
		}
	}

	return normalized
}


// clamp restricts a value to the [min, max] range.
func clamp(value, min, max float64) float64 {
	if value < min {
		return min
	} else if value > max {
		return max
	}
	return value
}
