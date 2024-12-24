package main

import (
	"bufio"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"io"
	"log"
	"math"
	"net/http"
	"os"
	"path/filepath"package main

                   import (
                   	"bufio"
                   	"fmt"
                   	"image"
                   	"image/color"
                   	"image/jpeg"
                   	"image/png"
                   	"io"
                   	"log"
                   	"math"
                   	"net/http"
                   	"os"
                   	"path/filepath"
                   	"strings"
                   	"sync"
                   	"time"

                   	"gopkg.in/yaml.v3"

                   	"github.com/nfnt/resize"
                   	"github.com/spf13/cobra"
                   	_ "golang.org/x/image/webp"
                   )

                   type Product struct {
                   	ID           int    `yaml:"id"`
                   	ExternalID   string `yaml:"external_id"`
                   	Name         string `yaml:"name"`
                   	ThumbnailURL string `yaml:"thumbnail_url"`
                   }

                   type Data struct {
                   	Products []Product `yaml:"data"`
                   }

                   var (
                   	downloadCount int
                   	countMutex    sync.Mutex
                   	client        *http.Client
                   )

                   func main() {
                   	// Initialize the HTTP client with a timeout
                   	client = &http.Client{
                   		Timeout: 30 * time.Second,
                   	}

                   	var rootCmd = &cobra.Command{
                   		Use:   "speedgo",
                   		Short: "Speedgo is a CLI tool for downloading, resizing, and normalizing images from YAML and TXT files.",
                   		Run: func(cmd *cobra.Command, args []string) {
                   			cmd.Help()
                   		},
                   	}

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

                   	rootCmd.AddCommand(yamlCmd, txtCmd)
                   	if err := rootCmd.Execute(); err != nil {
                   		log.Fatalf("Error executing command: %v", err)
                   	}
                   }

                   func processYAML(inputDir, outputDir string) {
                   	startTime := time.Now()
                   	err := os.MkdirAll(outputDir, os.ModePerm)
                   	if err != nil {
                   		log.Fatalf("Failed to create output directory: %v", err)
                   	}

                   	// Initialize WaitGroups and channels
                   	var downloaderWg sync.WaitGroup
                   	var processorWg sync.WaitGroup
                   	numWorkers := runtime.NumCPU() * 4
                   	imgChan := make(chan string, numWorkers*2)
                   	processChan := make(chan string, numWorkers*2)

                   	// Start downloader workers
                   	for i := 0; i < numWorkers; i++ {
                   		downloaderWg.Add(1)
                   		go downloaderWorker(&downloaderWg, imgChan, processChan, outputDir)
                   	}

                   	// Start processor workers
                   	for i := 0; i < numWorkers; i++ {
                   		processorWg.Add(1)
                   		go processorWorker(&processorWg, processChan)
                   	}

                   	// Close processChan after all downloaders are done
                   	go func() {
                   		downloaderWg.Wait()
                   		close(processChan)
                   	}()

                   	entries, err := os.ReadDir(inputDir)
                   	if err != nil {
                   		log.Fatalf("Failed to read input directory: %v", err)
                   	}

                   	for _, entry := range entries {
                   		if !entry.IsDir() && strings.ToLower(filepath.Ext(entry.Name())) == ".yaml" {
                   			filePath := filepath.Join(inputDir, entry.Name())
                   			processYAMLFile(filePath, imgChan)
                   		}
                   	}

                   	close(imgChan)     // Signal downloader workers no more images
                   	processorWg.Wait() // Wait for all processor workers to finish

                   	elapsed := time.Since(startTime)
                   	fmt.Printf("Successfully downloaded and processed %d images in %s\n", downloadCount, elapsed)
                   }

                   func processYAMLFile(filePath string, imgChan chan<- string) {
                   	content, err := os.ReadFile(filePath)
                   	if err != nil {
                   		log.Printf("Failed to read file %s: %v", filePath, err)
                   		return
                   	}

                   	var data Data
                   	err = yaml.Unmarshal(content, &data)
                   	if err != nil {
                   		log.Printf("Failed to unmarshal YAML file %s: %v", filePath, err)
                   		return
                   	}

                   	for _, product := range data.Products {
                   		if product.ThumbnailURL != "" {
                   			imgChan <- product.ThumbnailURL
                   		}
                   	}
                   }

                   func processTXT(inputFile, outputDir string) {
                   	startTime := time.Now()
                   	err := os.MkdirAll(outputDir, os.ModePerm)
                   	if err != nil {
                   		log.Fatalf("Failed to create output directory: %v", err)
                   	}

                   	file, err := os.Open(inputFile)
                   	if err != nil {
                   		log.Fatalf("Failed to open input file: %v", err)
                   	}
                   	defer file.Close()

                   	// Initialize WaitGroups and channels
                   	var downloaderWg sync.WaitGroup
                   	var processorWg sync.WaitGroup
                   	numWorkers := runtime.NumCPU() * 4
                   	imgChan := make(chan string, numWorkers*2)
                   	processChan := make(chan string, numWorkers*2)

                   	// Start downloader workers
                   	for i := 0; i < numWorkers; i++ {
                   		downloaderWg.Add(1)
                   		go downloaderWorker(&downloaderWg, imgChan, processChan, outputDir)
                   	}

                   	// Start processor workers
                   	for i := 0; i < numWorkers; i++ {
                   		processorWg.Add(1)
                   		go processorWorker(&processorWg, processChan)
                   	}

                   	// Close processChan after all downloaders are done
                   	go func() {
                   		downloaderWg.Wait()
                   		close(processChan)
                   	}()

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

                   	close(imgChan)     // Signal downloader workers no more images
                   	processorWg.Wait() // Wait for all processor workers to finish

                   	elapsed := time.Since(startTime)
                   	fmt.Printf("Successfully downloaded and processed %d images in %s\n", downloadCount, elapsed)
                   }

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

                   func processorWorker(wg *sync.WaitGroup, processChan <-chan string) {
                   	defer wg.Done()
                   	for filePath := range processChan {
                   		err := resizeAndNormalizeImage(filePath)
                   		if err != nil {
                   			log.Printf("Error processing %s: %v", filePath, err)
                   			continue
                   		}
                   	}
                   }

                   func downloadImage(url string, outputDir string) (string, error) {
                   	response, err := client.Get(url)
                   	if err != nil {
                   		return "", fmt.Errorf("failed to download image: %w", err)
                   	}
                   	defer response.Body.Close()

                   	if response.StatusCode != http.StatusOK {
                   		return "", fmt.Errorf("failed to download image: %s", response.Status)
                   	}

                   	// Extract filename from URL
                   	fileName := extractFileName(url)
                   	if fileName == "" {
                   		fileName = fmt.Sprintf("image_%d", time.Now().UnixNano())
                   	} else {
                   		// Ensure the filename is safe
                   		fileName = sanitizeFileName(fileName)
                   	}

                   	// Handle duplicate filenames
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

                   	file, err := os.Create(filePath)
                   	if err != nil {
                   		return "", fmt.Errorf("failed to create file %s: %w", filePath, err)
                   	}
                   	defer file.Close()

                   	_, err = io.Copy(file, response.Body)
                   	if err != nil {
                   		return "", fmt.Errorf("failed to save image %s: %w", filePath, err)
                   	}

                   	countMutex.Lock()
                   	downloadCount++
                   	countMutex.Unlock()

                   	log.Printf("Successfully downloaded %s", filePath)
                   	return filePath, nil
                   }

                   func extractFileName(url string) string {
                   	parts := strings.Split(url, "/")
                   	if len(parts) == 0 {
                   		return ""
                   	}
                   	fileName := parts[len(parts)-1]
                   	fileName = strings.Split(fileName, "?")[0] // Remove query parameters
                   	return fileName
                   }

                   func sanitizeFileName(name string) string {
                   	// Replace any invalid characters with underscores
                   	return strings.Map(func(r rune) rune {
                   		if strings.ContainsRune(`<>:"/\|?*`, r) || r < 32 {
                   			return '_'
                   		}
                   		return r
                   	}, name)
                   }

                   func resizeAndNormalizeImage(filePath string) error {
                   	file, err := os.Open(filePath)
                   	if err != nil {
                   		return fmt.Errorf("failed to open image file: %w", err)
                   	}
                   	defer file.Close()

                   	img, format, err := image.Decode(file)
                   	if err != nil {
                   		return fmt.Errorf("failed to decode image file: %w", err)
                   	}

                   	// Resize the image to half its original dimensions
                   	newWidth := img.Bounds().Dx() / 2
                   	newHeight := img.Bounds().Dy() / 2

                   	resizedImg := resize.Resize(uint(newWidth), uint(newHeight), img, resize.Lanczos3)

                   	// Normalize the image
                   	normalizedImg := normalizeImage(resizedImg)

                   	// Determine output file format
                   	var outputFilePath string
                   	switch strings.ToLower(format) {
                   	case "jpeg", "jpg":
                   		outputFilePath = filePath // Overwrite the original file
                   	case "png":
                   		outputFilePath = filePath // Overwrite the original file
                   	case "webp":
                   		// Convert WEBP to JPEG for normalization
                   		outputFilePath = strings.TrimSuffix(filePath, filepath.Ext(filePath)) + ".jpg"
                   	default:
                   		return fmt.Errorf("unsupported image format: %s", format)
                   	}

                   	out, err := os.Create(outputFilePath)
                   	if err != nil {
                   		return fmt.Errorf("failed to create resized image file %s: %w", outputFilePath, err)
                   	}
                   	defer out.Close()

                   	// Encode the normalized image
                   	switch strings.ToLower(format) {
                   	case "jpeg", "jpg", "webp":
                   		err = jpeg.Encode(out, normalizedImg, &jpeg.Options{Quality: 90})
                   	case "png":
                   		err = png.Encode(out, normalizedImg)
                   	default:
                   		return fmt.Errorf("unsupported image format: %s", format)
                   	}

                   	if err != nil {
                   		return fmt.Errorf("failed to encode resized image file %s: %w", outputFilePath, err)
                   	}

                   	// If format was WEBP and converted to JPEG, delete the original WEBP file
                   	if strings.ToLower(format) == "webp" {
                   		err = os.Remove(filePath)
                   		if err != nil {
                   			log.Printf("Warning: failed to delete original WEBP file %s: %v", filePath, err)
                   		}
                   	}

                   	log.Printf("Successfully resized and normalized %s", outputFilePath)
                   	return nil
                   }

                   func normalizeImage(img image.Image) image.Image {
                   	bounds := img.Bounds()
                   	normalized := image.NewRGBA(bounds)

                   	// Initialize variables to calculate mean and std dev
                   	var rTotal, gTotal, bTotal float64
                   	var rSquares, gSquares, bSquares float64
                   	totalPixels := float64(bounds.Dx() * bounds.Dy())

                   	// First pass: calculate sum and sum of squares for each channel
                   	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
                   		for x := bounds.Min.X; x < bounds.Max.X; x++ {
                   			r, g, b, _ := img.At(x, y).RGBA()
                   			r8 := float64(r>>8) / 255.0
                   			g8 := float64(g>>8) / 255.0
                   			b8 := float64(b>>8) / 255.0

                   			rTotal += r8
                   			gTotal += g8
                   			bTotal += b8

                   			rSquares += r8 * r8
                   			gSquares += g8 * g8
                   			bSquares += b8 * b8
                   		}
                   	}

                   	// Calculate mean
                   	rMean := rTotal / totalPixels
                   	gMean := gTotal / totalPixels
                   	bMean := bTotal / totalPixels

                   	// Calculate standard deviation
                   	rStd := math.Sqrt((rSquares / totalPixels) - (rMean * rMean))
                   	gStd := math.Sqrt((gSquares / totalPixels) - (gMean * gMean))
                   	bStd := math.Sqrt((bSquares / totalPixels) - (bMean * bMean))

                   	// Second pass: normalize pixels
                   	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
                   		for x := bounds.Min.X; x < bounds.Max.X; x++ {
                   			r, g, b, a := img.At(x, y).RGBA()
                   			r8 := float64(r>>8) / 255.0
                   			g8 := float64(g>>8) / 255.0
                   			b8 := float64(b>>8) / 255.0

                   			// Apply standardization
                   			if rStd != 0 {
                   				r8 = (r8 - rMean) / rStd
                   			}

	"strings"
	"sync"
	"time"

	"gopkg.in/yaml.v3"

	"github.com/nfnt/resize"
	"github.com/spf13/cobra"
	_ "golang.org/x/image/webp"
)

type Product struct {
	ID           int    `yaml:"id"`
	ExternalID   string `yaml:"external_id"`
	Name         string `yaml:"name"`
	ThumbnailURL string `yaml:"thumbnail_url"`
}

type Data struct {
	Products []Product `yaml:"data"`
}

var (
	downloadCount int
	countMutex    sync.Mutex
	client        *http.Client
)

func main() {
	// Initialize the HTTP client with a timeout
	client = &http.Client{
		Timeout: 30 * time.Second,
	}

	var rootCmd = &cobra.Command{
		Use:   "speedgo",
		Short: "Speedgo is a CLI tool for downloading, resizing, and normalizing images from YAML and TXT files.",
		Run: func(cmd *cobra.Command, args []string) {
			cmd.Help()
		},
	}

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

	rootCmd.AddCommand(yamlCmd, txtCmd)
	if err := rootCmd.Execute(); err != nil {
		log.Fatalf("Error executing command: %v", err)
	}
}

func processYAML(inputDir, outputDir string) {
	startTime := time.Now()
	err := os.MkdirAll(outputDir, os.ModePerm)
	if err != nil {
		log.Fatalf("Failed to create output directory: %v", err)
	}

	// Initialize WaitGroups and channels
	var downloaderWg sync.WaitGroup
	var processorWg sync.WaitGroup
	numWorkers := runtime.NumCPU() * 4
	imgChan := make(chan string, numWorkers*2)
	processChan := make(chan string, numWorkers*2)

	// Start downloader workers
	for i := 0; i < numWorkers; i++ {
		downloaderWg.Add(1)
		go downloaderWorker(&downloaderWg, imgChan, processChan, outputDir)
	}

	// Start processor workers
	for i := 0; i < numWorkers; i++ {
		processorWg.Add(1)
		go processorWorker(&processorWg, processChan)
	}

	// Close processChan after all downloaders are done
	go func() {
		downloaderWg.Wait()
		close(processChan)
	}()

	entries, err := os.ReadDir(inputDir)
	if err != nil {
		log.Fatalf("Failed to read input directory: %v", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() && strings.ToLower(filepath.Ext(entry.Name())) == ".yaml" {
			filePath := filepath.Join(inputDir, entry.Name())
			processYAMLFile(filePath, imgChan)
		}
	}

	close(imgChan)     // Signal downloader workers no more images
	processorWg.Wait() // Wait for all processor workers to finish

	elapsed := time.Since(startTime)
	fmt.Printf("Successfully downloaded and processed %d images in %s\n", downloadCount, elapsed)
}

func processYAMLFile(filePath string, imgChan chan<- string) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		log.Printf("Failed to read file %s: %v", filePath, err)
		return
	}

	var data Data
	err = yaml.Unmarshal(content, &data)
	if err != nil {
		log.Printf("Failed to unmarshal YAML file %s: %v", filePath, err)
		return
	}

	for _, product := range data.Products {
		if product.ThumbnailURL != "" {
			imgChan <- product.ThumbnailURL
		}
	}
}

func processTXT(inputFile, outputDir string) {
	startTime := time.Now()
	err := os.MkdirAll(outputDir, os.ModePerm)
	if err != nil {
		log.Fatalf("Failed to create output directory: %v", err)
	}

	file, err := os.Open(inputFile)
	if err != nil {
		log.Fatalf("Failed to open input file: %v", err)
	}
	defer file.Close()

	// Initialize WaitGroups and channels
	var downloaderWg sync.WaitGroup
	var processorWg sync.WaitGroup
	numWorkers := runtime.NumCPU() * 4
	imgChan := make(chan string, numWorkers*2)
	processChan := make(chan string, numWorkers*2)

	// Start downloader workers
	for i := 0; i < numWorkers; i++ {
		downloaderWg.Add(1)
		go downloaderWorker(&downloaderWg, imgChan, processChan, outputDir)
	}

	// Start processor workers
	for i := 0; i < numWorkers; i++ {
		processorWg.Add(1)
		go processorWorker(&processorWg, processChan)
	}

	// Close processChan after all downloaders are done
	go func() {
		downloaderWg.Wait()
		close(processChan)
	}()

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

	close(imgChan)     // Signal downloader workers no more images
	processorWg.Wait() // Wait for all processor workers to finish

	elapsed := time.Since(startTime)
	fmt.Printf("Successfully downloaded and processed %d images in %s\n", downloadCount, elapsed)
}

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

func processorWorker(wg *sync.WaitGroup, processChan <-chan string) {
	defer wg.Done()
	for filePath := range processChan {
		err := resizeAndNormalizeImage(filePath)
		if err != nil {
			log.Printf("Error processing %s: %v", filePath, err)
			continue
		}
	}
}

func downloadImage(url string, outputDir string) (string, error) {
	response, err := client.Get(url)
	if err != nil {
		return "", fmt.Errorf("failed to download image: %w", err)
	}
	defer response.Body.Close()

	if response.StatusCode != http.StatusOK {
		return "", fmt.Errorf("failed to download image: %s", response.Status)
	}

	// Extract filename from URL
	fileName := extractFileName(url)
	if fileName == "" {
		fileName = fmt.Sprintf("image_%d", time.Now().UnixNano())
	} else {
		// Ensure the filename is safe
		fileName = sanitizeFileName(fileName)
	}

	// Handle duplicate filenames
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

	file, err := os.Create(filePath)
	if err != nil {
		return "", fmt.Errorf("failed to create file %s: %w", filePath, err)
	}
	defer file.Close()

	_, err = io.Copy(file, response.Body)
	if err != nil {
		return "", fmt.Errorf("failed to save image %s: %w", filePath, err)
	}

	countMutex.Lock()
	downloadCount++
	countMutex.Unlock()

	log.Printf("Successfully downloaded %s", filePath)
	return filePath, nil
}

func extractFileName(url string) string {
	parts := strings.Split(url, "/")
	if len(parts) == 0 {
		return ""
	}
	fileName := parts[len(parts)-1]
	fileName = strings.Split(fileName, "?")[0] // Remove query parameters
	return fileName
}

func sanitizeFileName(name string) string {
	// Replace any invalid characters with underscores
	return strings.Map(func(r rune) rune {
		if strings.ContainsRune(`<>:"/\|?*`, r) || r < 32 {
			return '_'
		}
		return r
	}, name)
}

func resizeAndNormalizeImage(filePath string) error {
	file, err := os.Open(filePath)
	if err != nil {
		return fmt.Errorf("failed to open image file: %w", err)
	}
	defer file.Close()

	img, format, err := image.Decode(file)
	if err != nil {
		return fmt.Errorf("failed to decode image file: %w", err)
	}

	// Resize the image to half its original dimensions
	newWidth := img.Bounds().Dx() / 2
	newHeight := img.Bounds().Dy() / 2

	resizedImg := resize.Resize(uint(newWidth), uint(newHeight), img, resize.Lanczos3)

	// Normalize the image
	normalizedImg := normalizeImage(resizedImg)

	// Determine output file format
	var outputFilePath string
	switch strings.ToLower(format) {
	case "jpeg", "jpg":
		outputFilePath = filePath // Overwrite the original file
	case "png":
		outputFilePath = filePath // Overwrite the original file
	case "webp":
		// Convert WEBP to JPEG for normalization
		outputFilePath = strings.TrimSuffix(filePath, filepath.Ext(filePath)) + ".jpg"
	default:
		return fmt.Errorf("unsupported image format: %s", format)
	}

	out, err := os.Create(outputFilePath)
	if err != nil {
		return fmt.Errorf("failed to create resized image file %s: %w", outputFilePath, err)
	}
	defer out.Close()

	// Encode the normalized image
	switch strings.ToLower(format) {
	case "jpeg", "jpg", "webp":
		err = jpeg.Encode(out, normalizedImg, &jpeg.Options{Quality: 90})
	case "png":
		err = png.Encode(out, normalizedImg)
	default:
		return fmt.Errorf("unsupported image format: %s", format)
	}

	if err != nil {
		return fmt.Errorf("failed to encode resized image file %s: %w", outputFilePath, err)
	}

	// If format was WEBP and converted to JPEG, delete the original WEBP file
	if strings.ToLower(format) == "webp" {
		err = os.Remove(filePath)
		if err != nil {
			log.Printf("Warning: failed to delete original WEBP file %s: %v", filePath, err)
		}
	}

	log.Printf("Successfully resized and normalized %s", outputFilePath)
	return nil
}

func normalizeImage(img image.Image) image.Image {
	bounds := img.Bounds()
	normalized := image.NewRGBA(bounds)

	// Initialize variables to calculate mean and std dev
	var rTotal, gTotal, bTotal float64
	var rSquares, gSquares, bSquares float64
	totalPixels := float64(bounds.Dx() * bounds.Dy())

	// First pass: calculate sum and sum of squares for each channel
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, _ := img.At(x, y).RGBA()
			r8 := float64(r>>8) / 255.0
			g8 := float64(g>>8) / 255.0
			b8 := float64(b>>8) / 255.0

			rTotal += r8
			gTotal += g8
			bTotal += b8

			rSquares += r8 * r8
			gSquares += g8 * g8
			bSquares += b8 * b8
		}
	}

	// Calculate mean
	rMean := rTotal / totalPixels
	gMean := gTotal / totalPixels
	bMean := bTotal / totalPixels

	// Calculate standard deviation
	rStd := math.Sqrt((rSquares / totalPixels) - (rMean * rMean))
	gStd := math.Sqrt((gSquares / totalPixels) - (gMean * gMean))
	bStd := math.Sqrt((bSquares / totalPixels) - (bMean * bMean))

	// Second pass: normalize pixels
	for y := bounds.Min.Y; y < bounds.Max.Y; y++ {
		for x := bounds.Min.X; x < bounds.Max.X; x++ {
			r, g, b, a := img.At(x, y).RGBA()
			r8 := float64(r>>8) / 255.0
			g8 := float64(g>>8) / 255.0
			b8 := float64(b>>8) / 255.0

			// Apply standardization
			if rStd != 0 {
				r8 = (r8 - rMean) / rStd
			}
			if gStd != 0 {
				g8 = (g8 - gMean) / gStd
			}
			if bStd != 0 {
				b8 = (b8 - bMean) / bStd
			}

			// Scale back to [0,1] with a balanced offset to preserve color integrity
			rNorm := clamp(r8*0.3+0.5, 0, 1) * 255.0
			gNorm := clamp(g8*0.3+0.5, 0, 1) * 255.0
			bNorm := clamp(b8*0.3+0.5, 0, 1) * 255.0

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
