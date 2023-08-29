package main

import (
	"compress/gzip"
	"crypto/sha256"
	"encoding/hex"
	"flag"
	"fmt"
	"io/fs"
	"os"
	"os/signal"
	"path/filepath"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
)

type Resource struct {
	Path        string
	Size        int64
	IsDir       bool
	IsSym       bool
	Permissions string
	Checksum    string
}

var (
	wg            = sync.WaitGroup{}
	sigCh         = make(chan os.Signal, 1)
	resCh         = make(chan Resource, runtime.GOMAXPROCS(runtime.NumCPU()))
	doneCh        = make(chan struct{}, 1)
	manifestFile  *os.File
	manifestDir   = flag.String("manifest-dir", "./manifests", "Directory to store manifests")
	outputPrefix  *string
	defaultPrefix = "manifest.txt"
)

func main() {
	outputPrefix = flag.String("outpre", "", "Prefix for generated files")
	if outputPrefix == nil || *outputPrefix == "" {
		outputPrefix = &defaultPrefix
	}
	flag.Usage = func() {
		fmt.Println("Usage: go run main.go [options]")
		fmt.Println("  options:")
		fmt.Println("  --manifest-dir: Directory to store manifests (default: ./manifests)")
		fmt.Println("  --outpre: Prefix for output filenames (default: manifest.txt)")
		fmt.Println("Example: go run main.go --manifest-dir=./manifests --output-prefix=myfile /path/to/directory")
	}
	flag.Parse()

	if len(flag.Args()) == 0 || flag.Arg(0) == "-h" || flag.Arg(0) == "--help" || flag.Arg(0) == "" || *manifestDir == "" || *outputPrefix == "" {
		flag.Usage()
		return
	}

	if _, err := os.Stat(*manifestDir); os.IsNotExist(err) {
		err := os.Mkdir(*manifestDir, os.ModePerm)
		if err != nil {
			fmt.Fprintf(os.Stderr, "%s%s", "FATAL ERROR: ", err)
			return
		}
	}

	signal.Notify(sigCh, syscall.SIGINT)
	go handleSignal()

	if _, err := os.Stat(filepath.Join(*manifestDir, *outputPrefix)); err == nil {
		newName := nextManifest()
		err := os.Rename(
			filepath.Join(*manifestDir, *outputPrefix),
			filepath.Join(*manifestDir, newName),
		)
		if err != nil {
			fmt.Printf("Failed to rename existing manifest: %v\n", err)
			return
		}
	}

	go writeManifest()

	home := os.Getenv("HOME")

	err := filepath.WalkDir(flag.Arg(0), func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		if strings.Contains(path, "/go/backups/") ||
			strings.Contains(path, "/go/manifests") ||
			strings.Contains(path, ":\\go\\backups") ||
			strings.Contains(path, ":\\go\\manifests") ||
			strings.Contains(path, *manifestDir) ||
			(home != "" && strings.Contains(path, filepath.Join(home, "go", "backups"))) ||
			(home != "" && strings.Contains(path, filepath.Join(home, "go", "manifests"))) {
			return nil
		}

		wg.Add(1)
		go func() {
			defer wg.Done()
			if err := createResource(path); err != nil {
				fmt.Printf("Error: %v\n", err)
			}
		}()
		return nil
	})

	wg.Wait()
	close(resCh)

	if err != nil {
		fmt.Printf("Error walking the path %v: %v\n", flag.Arg(0), err)
	}

	<-doneCh
}

func writeManifest() {
	f, err := os.Create(filepath.Join(*manifestDir, *outputPrefix))
	if err != nil {
		fmt.Println("Error creating manifest file:", err)
		return
	}

	manifestFile = f

	var resources []Resource
	for res := range resCh {
		resources = append(resources, res)
	}

	sort.Slice(resources, func(i, j int) bool {
		return resources[i].Path < resources[j].Path
	})

	for _, res := range resources {
		_, err := fmt.Fprintf(f, "%s|%s|%d|%t|%t|%s\n", res.Checksum, res.Permissions, res.Size, res.IsDir, res.IsSym, res.Path)
		if err != nil {
			fmt.Println("Error writing to manifest file:", err)
			return
		}
	}

	f.Seek(0, 0)
	defer f.Close()

	fileBytes, err := os.ReadFile(*outputPrefix)
	if err != nil {
		return
	}
	hash := sha256.Sum256(fileBytes)
	checksum := hex.EncodeToString(hash[:])

	var c *os.File
	c, err = os.Create(fmt.Sprintf("%s.checksum", *outputPrefix))
	if err != nil {
		fmt.Println("Error creating manifest checksum file: ", err)
		return
	}

	fmt.Fprintf(c, "%s", checksum)
	defer c.Close()

	// Create the compressed manifest.txt.gz
	gzFile, err := os.Create(fmt.Sprintf("%s.gz", *outputPrefix))
	if err != nil {
		fmt.Println("Error creating compressed manifest file:", err)
		return
	}
	defer gzFile.Close()

	gzWriter := gzip.NewWriter(gzFile)
	defer gzWriter.Close()

	originalBytes, err := os.ReadFile(*outputPrefix)
	if err != nil {
		fmt.Println("Error reading original manifest file:", err)
		return
	}

	_, err = gzWriter.Write(originalBytes)
	if err != nil {
		fmt.Println("Error writing to compressed manifest file:", err)
		return
	}
	gzWriter.Close()

	compressedBytes, err := os.ReadFile(fmt.Sprintf("%s.gz", *outputPrefix))
	if err != nil {
		fmt.Println("Error reading compressed manifest file:", err)
		return
	}
	compressedHash := sha256.Sum256(compressedBytes)
	compressedChecksum := hex.EncodeToString(compressedHash[:])

	compressedChecksumFile, err := os.Create(fmt.Sprintf("%s.gz.checksum", *outputPrefix))
	if err != nil {
		fmt.Println("Error creating compressed manifest checksum file: ", err)
		return
	}
	defer compressedChecksumFile.Close()

	fmt.Fprintf(compressedChecksumFile, "%s", compressedChecksum)

	err = os.Remove(*outputPrefix)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to clean up original manifest file %v with err: %v\n", *outputPrefix, err)
		return
	}

	doneCh <- struct{}{}
}

func handleSignal() {
	<-sigCh
	fmt.Println("Interrupt received. Cleaning up...")
	if err := os.Rename(*outputPrefix, fmt.Sprintf("%s%s", *outputPrefix, ".partial")); err != nil {
		fmt.Println("Error renaming file:", err)
	}
	close(resCh)
	manifestFile.Close()
	os.Exit(1)
}

func nextManifest() string {
	var maxIndex int

	err := filepath.WalkDir(*manifestDir, func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		base := filepath.Base(path)
		matched, err := filepath.Match(fmt.Sprintf("%s%s%s", "[0-9]*.", *outputPrefix, ".*"), base)
		if err != nil {
			return err
		}
		if matched {
			parts := strings.Split(base, ".")
			if len(parts) > 0 {
				indexPart := strings.Split(parts[0], "-")[0]
				index, err := strconv.Atoi(indexPart)
				if err == nil && index > maxIndex {
					maxIndex = index
				}
			}
		}
		return nil
	})

	defaultName := "manifest.txt"
	if len(*outputPrefix) > 0 && *outputPrefix != defaultName {
		defaultName = *outputPrefix
	}

	if err != nil {
		fmt.Printf("Error walking the directory: %v\n", err)
		return defaultName
	}

	return fmt.Sprintf("%03d.%s", maxIndex+1, defaultName)
}

func createResource(path string) error {
	info, err := os.Stat(path)
	if err != nil {
		return err
	}
	perm := info.Mode().Perm()
	var fileBytes []byte
	if !info.IsDir() {
		fileBytes, err = os.ReadFile(path)
		if err != nil {
			return err
		}
	}

	resCh <- Resource{
		Path:        path,
		Size:        info.Size(),
		IsDir:       info.IsDir(),
		IsSym:       (info.Mode() & os.ModeSymlink) != 0,
		Permissions: fmt.Sprintf("%o", perm),
		Checksum: func(fileBytes []byte) string {
			hash := sha256.Sum256(fileBytes)
			return hex.EncodeToString(hash[:])
		}(fileBytes),
	}
	fileBytes = []byte{}
	return nil
}
