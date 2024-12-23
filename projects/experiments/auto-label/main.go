package main

import (
	"bufio"
	"fmt"
	"image"
	"image/color"
	"image/jpeg"
	"image/png"
	"io"
	"math"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"

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
	client = &http.Client{}
	var rootCmd = &cobra.Command{
		Use:   "speedgo",
		Short: "Speedgo is a CLI tool for downloading, resizing, and normalizing images from YAML and TXT files.",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Please use a subcommand: yaml or txt")
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
	err := rootCmd.Execute()
	if err != nil {
		return
	}
}

func processYAML(inputDir, outputDir string) {
	err := os.MkdirAll(outputDir, os.ModePerm)
	if err != nil {
		fmt.Printf("Failed to create output directory: %v\n", err)
		return
	}

	// Initialize separate WaitGroups for downloader and processor workers
	var downloaderWg sync.WaitGroup
	var processorWg sync.WaitGroup
	numWorkers := runtime.NumCPU() * 4 // Adjust based on system capabilities
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

	// Start a goroutine to close processChan after all downloaders are done
	go func() {
		downloaderWg.Wait()
		close(processChan)
	}()

	entries, err := os.ReadDir(inputDir)
	if err != nil {
		fmt.Printf("Failed to read input directory: %v\n", err)
		return
	}

	for _, entry := range entries {
		if !entry.IsDir() && strings.ToLower(filepath.Ext(entry.Name())) == ".yaml" {
			filePath := filepath.Join(inputDir, entry.Name())
			processYAMLFile(filePath, imgChan)
		}
	}

	close(imgChan)     // Signal downloader workers no more images
	processorWg.Wait() // Wait for all processor workers to finish

	fmt.Printf("Successfully downloaded and processed %d images\n", downloadCount)
}

func processYAMLFile(filePath string, imgChan chan<- string) {
	content, err := os.ReadFile(filePath)
	if err != nil {
		fmt.Printf("Failed to read file %s: %v\n", filePath, err)
		return
	}

	var data Data
	err = yaml.Unmarshal(content, &data)
	if err != nil {
		fmt.Printf("Failed to unmarshal YAML file %s: %v\n", filePath, err)
		return
	}

	for _, product := range data.Products {
		if product.ThumbnailURL != "" {
			imgChan <- product.ThumbnailURL
		}
	}
}

func processTXT(inputFile, outputDir string) {
	err := os.MkdirAll(outputDir, os.ModePerm)
	if err != nil {
		fmt.Printf("Failed to create output directory: %v\n", err)
		return
	}

	file, err := os.Open(inputFile)
	if err != nil {
		fmt.Printf("Failed to open input file: %v\n", err)
		return
	}
	defer file.Close()

	// Initialize separate WaitGroups for downloader and processor workers
	var downloaderWg sync.WaitGroup
	var processorWg sync.WaitGroup
	numWorkers := runtime.NumCPU() * 4 // Adjust based on system capabilities
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

	// Start a goroutine to close processChan after all downloaders are done
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
		fmt.Printf("Error reading input file: %v\n", err)
	}

	close(imgChan)     // Signal downloader workers no more images
	processorWg.Wait() // Wait for all processor workers to finish

	fmt.Printf("Successfully downloaded and processed %d images\n", downloadCount)
}

func downloaderWorker(wg *sync.WaitGroup, imgChan <-chan string, processChan chan<- string, outputDir string) {
	defer wg.Done()
	for url := range imgChan {
		filePath, err := downloadImage(url, outputDir)
		if err != nil {
			fmt.Printf("Error downloading %s: %v\n", url, err)
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
			fmt.Printf("Error processing %s: %v\n", filePath, err)
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

	fileName := filepath.Base(strings.Split(url, "?")[0])
	if fileName == "" || fileName == "/" || fileName == "." {
		fileName = fmt.Sprintf("image_%d", downloadCount+1)
	}

	filePath := filepath.Join(outputDir, fileName)

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

	fmt.Printf("Successfully downloaded %s\n", filePath)
	return filePath, nil
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
			fmt.Printf("Warning: failed to delete original WEBP file %s: %v\n", filePath, err)
		}
	}

	fmt.Printf("Successfully resized and normalized %s\n", outputFilePath)
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
	rStd := sqrt((rSquares / totalPixels) - (rMean * rMean))
	gStd := sqrt((gSquares / totalPixels) - (gMean * gMean))
	bStd := sqrt((bSquares / totalPixels) - (bMean * bMean))

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

// sqrt computes the square root of a value.
func sqrt(value float64) float64 {
	return math.Sqrt(value)
}
