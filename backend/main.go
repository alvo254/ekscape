package main

import (
	"fmt"
	"log"
	"os"
	"path/filepath"
	"time"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/fsnotify/fsnotify"
)

const (
	watchDir   = "./watchfolder"
	bucketName = "your-bucket-name"
	awsRegion  = "us-west-2" // Change this to your desired AWS region
)

func main() {
	// Create a new AWS session
	sess, err := session.NewSession(&aws.Config{
		Region: aws.String(awsRegion),
	})
	if err != nil {
		log.Fatalf("Failed to create AWS session: %v", err)
	}

	// Create S3 service client
	svc := s3.New(sess)

	// Create a new file watcher
	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatalf("Failed to create watcher: %v", err)
	}
	defer watcher.Close()

	// Start watching the directory
	go watchDirectory(watcher, svc)

	// Add the directory to the watcher
	err = watcher.Add(watchDir)
	if err != nil {
		log.Fatalf("Failed to add directory to watcher: %v", err)
	}

	fmt.Printf("Watching directory: %s\n", watchDir)
	fmt.Println("Press Ctrl+C to stop")

	// Keep the program running
	select {}
}

func watchDirectory(watcher *fsnotify.Watcher, svc *s3.S3) {
	for {
		select {
		case event, ok := <-watcher.Events:
			if !ok {
				return
			}
			if event.Op&fsnotify.Write == fsnotify.Write || event.Op&fsnotify.Create == fsnotify.Create {
				log.Println("Modified file:", event.Name)
				uploadToS3(svc, event.Name)
			}
		case err, ok := <-watcher.Errors:
			if !ok {
				return
			}
			log.Println("Error:", err)
		}
	}
}

func uploadToS3(svc *s3.S3, filePath string) {
	file, err := os.Open(filePath)
	if err != nil {
		log.Printf("Failed to open file %s: %v", filePath, err)
		return
	}
	defer file.Close()

	_, fileName := filepath.Split(filePath)

	_, err = svc.PutObject(&s3.PutObjectInput{
		Bucket: aws.String(bucketName),
		Key:    aws.String(fileName),
		Body:   file,
	})

	if err != nil {
		log.Printf("Failed to upload file %s: %v", fileName, err)
	} else {
		log.Printf("Successfully uploaded %s to S3", fileName)
	}
}