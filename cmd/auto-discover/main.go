package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
)

func main() {
	var (
		token         = flag.String("token", os.Getenv("GITHUB_TOKEN"), "GitHub token")
		repo          = flag.String("repo", os.Getenv("GITHUB_REPOSITORY"), "Repository (owner/repo)")
		allowlistPath = flag.String("allowlist", "allowlist.txt", "Path to allowlist file")
		denylistPath  = flag.String("denylist", "denylist.txt", "Path to denylist file")
		dryRun        = flag.Bool("dry-run", false, "Dry run mode (don't create issues)")
		workers       = flag.Int("workers", 5, "Number of parallel workers for processing repositories")
	)
	flag.Parse()

	if *token == "" {
		log.Fatal("GitHub token is required (set GITHUB_TOKEN or use -token flag)")
	}

	if *repo == "" {
		log.Fatal("Repository is required (set GITHUB_REPOSITORY or use -repo flag)")
	}

	ctx := context.Background()

	config := &Config{
		Token:         *token,
		Repository:    *repo,
		AllowlistPath: *allowlistPath,
		DenylistPath:  *denylistPath,
		DryRun:        *dryRun,
		Workers:       *workers,
	}

	discoverer := NewDiscoverer(config)

	if err := discoverer.Run(ctx); err != nil {
		log.Fatalf("Error running auto-discovery: %v", err)
	}

	fmt.Println("✨ Auto-discovery complete!")
}
