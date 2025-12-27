package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"
)

const (
	defaultWorkers    = 5
	rateLimitInterval = 100 * time.Millisecond // 10 requests per second
	minRepoPathParts  = 2
)

type Config struct {
	Token         string
	Repository    string
	AllowlistPath string
	DenylistPath  string
	DryRun        bool
	Workers       int
	BaseURL       string
	PerPage       int
}

type Discoverer struct {
	config      *Config
	httpClient  *http.Client
	allowlist   map[string]bool
	denylist    map[string]bool
	rateLimiter *time.Ticker
}

type GitHubClient interface {
	SearchCode(ctx context.Context, query string) ([]CodeSearchResult, error)
	ListIssues(ctx context.Context, repo string, labels []string) ([]Issue, error)
	FetchFile(ctx context.Context, repo, path string) ([]byte, error)
	CreateIssue(ctx context.Context, repo string, issue *NewIssue) error
}

type CodeSearchResult struct {
	Repository struct {
		FullName string `json:"full_name"`
	} `json:"repository"`
}

type Issue struct {
	Title string `json:"title"`
}

type NewIssue struct {
	Title  string   `json:"title"`
	Body   string   `json:"body"`
	Labels []string `json:"labels"`
}

func NewDiscoverer(config *Config) *Discoverer {
	if config.Workers <= 0 {
		config.Workers = defaultWorkers
	}

	if config.BaseURL == "" {
		config.BaseURL = "https://api.github.com"
	}

	if config.PerPage <= 0 {
		config.PerPage = 100
	}

	return &Discoverer{
		config:      config,
		httpClient:  &http.Client{},
		allowlist:   make(map[string]bool),
		denylist:    make(map[string]bool),
		rateLimiter: time.NewTicker(rateLimitInterval),
	}
}

func (d *Discoverer) Run(ctx context.Context) error {
	// Load allowlist and denylist
	if err := d.loadAllowlist(); err != nil {
		return fmt.Errorf("loading allowlist: %w", err)
	}

	if err := d.loadDenylist(); err != nil {
		return fmt.Errorf("loading denylist: %w", err)
	}

	// Search for repositories
	fmt.Println("🔍 Searching for repositories with .enhansome.jsonc...")

	repos, err := d.searchRepositories(ctx)
	if err != nil {
		return fmt.Errorf("searching repositories: %w", err)
	}

	fmt.Printf("Found %d repositories\n", len(repos))

	// Filter repositories
	fmt.Println("\n🔎 Filtering repositories...")

	newRepos := d.filterRepositories(repos)
	fmt.Printf("Found %d new repositories to process\n", len(newRepos))

	if len(newRepos) == 0 {
		fmt.Println("No new repositories to process")
		return nil
	}

	// Get existing issues
	fmt.Println("\n📋 Checking for existing issues...")

	existingIssues, err := d.getExistingIssues(ctx)
	if err != nil {
		return fmt.Errorf("getting existing issues: %w", err)
	}

	// Create issues for new repositories
	fmt.Println("\n📝 Creating issues...")

	return d.createIssues(ctx, newRepos, existingIssues)
}

func (d *Discoverer) loadAllowlist() error {
	file, err := os.Open(d.config.AllowlistPath)
	if err != nil {
		return fmt.Errorf("opening allowlist file: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		// Extract owner/repo from owner/repo/README.json
		parts := strings.Split(line, "/")
		if len(parts) >= minRepoPathParts {
			repo := parts[0] + "/" + parts[1]
			d.allowlist[repo] = true
		}
	}

	if scanErr := scanner.Err(); scanErr != nil {
		return fmt.Errorf("scanning allowlist file: %w", scanErr)
	}

	return nil
}

func (d *Discoverer) loadDenylist() error {
	file, err := os.Open(d.config.DenylistPath)
	if err != nil {
		if os.IsNotExist(err) {
			return nil // Denylist is optional
		}
		return fmt.Errorf("opening denylist file: %w", err)
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		d.denylist[line] = true
	}

	if scanErr := scanner.Err(); scanErr != nil {
		return fmt.Errorf("scanning denylist file: %w", scanErr)
	}

	return nil
}

func (d *Discoverer) searchRepositories(ctx context.Context) ([]string, error) {
	query := "filename:.enhansome.jsonc path:/ registryIndexing"
	repoMap := make(map[string]bool)

	for page := 1; ; page++ {
		pageResults, hasMore, err := d.searchRepositoriesPage(ctx, query, page, d.config.PerPage)
		if err != nil {
			return nil, err
		}

		for _, repo := range pageResults {
			repoMap[repo] = true
		}

		if !hasMore {
			break
		}
	}

	repos := make([]string, 0, len(repoMap))
	for repo := range repoMap {
		repos = append(repos, repo)
	}

	return repos, nil
}

func (d *Discoverer) searchRepositoriesPage(
	ctx context.Context,
	query string,
	page, perPage int,
) ([]string, bool, error) {
	searchURL := fmt.Sprintf(
		"%s/search/code?q=%s&per_page=%d&page=%d",
		d.config.BaseURL, url.QueryEscape(query), perPage, page,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, searchURL, nil)
	if err != nil {
		return nil, false, fmt.Errorf("creating search request: %w", err)
	}

	req.Header.Set("Authorization", "token "+d.config.Token)
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := d.httpClient.Do(req)
	if err != nil {
		return nil, false, fmt.Errorf("executing search request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)

		return nil, false, fmt.Errorf("GitHub API returned %d: %s", resp.StatusCode, string(body))
	}

	var result struct {
		Items      []CodeSearchResult `json:"items"`
		TotalCount int                `json:"total_count"`
	}

	if decodeErr := json.NewDecoder(resp.Body).Decode(&result); decodeErr != nil {
		return nil, false, fmt.Errorf("decoding search results: %w", decodeErr)
	}

	repos := make([]string, 0, len(result.Items))
	for _, item := range result.Items {
		repos = append(repos, item.Repository.FullName)
	}

	hasMore := len(result.Items) == perPage && page*perPage < result.TotalCount

	return repos, hasMore, nil
}

func (d *Discoverer) filterRepositories(repos []string) []string {
	var newRepos []string

	for _, repo := range repos {
		if d.allowlist[repo] {
			fmt.Printf("⏭️  Skipping %s (already in allowlist)\n", repo)
			continue
		}

		// Check if in denylist
		if d.denylist[repo] {
			fmt.Printf("🚫 Skipping %s (in denylist)\n", repo)
			continue
		}

		fmt.Printf("✅ New repo found: %s\n", repo)
		newRepos = append(newRepos, repo)
	}

	return newRepos
}

func (d *Discoverer) getExistingIssues(ctx context.Context) (map[string]bool, error) {
	existingIssues := make(map[string]bool)

	for page := 1; ; page++ {
		issues, hasMore, err := d.getExistingIssuesPage(ctx, page, d.config.PerPage)
		if err != nil {
			return nil, err
		}

		for _, issue := range issues {
			if repo, found := strings.CutPrefix(issue.Title, "Auto-Discovery: "); found {
				existingIssues[repo] = true
			}
		}

		if !hasMore {
			break
		}
	}

	return existingIssues, nil
}

func (d *Discoverer) getExistingIssuesPage(
	ctx context.Context,
	page, perPage int,
) ([]Issue, bool, error) {
	url := fmt.Sprintf(
		"%s/repos/%s/issues?state=open&labels=auto-discovery&per_page=%d&page=%d",
		d.config.BaseURL, d.config.Repository, perPage, page,
	)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, false, fmt.Errorf("creating issues request: %w", err)
	}

	req.Header.Set("Authorization", "token "+d.config.Token)
	req.Header.Set("Accept", "application/vnd.github.v3+json")

	resp, err := d.httpClient.Do(req)
	if err != nil {
		return nil, false, fmt.Errorf("executing issues request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)

		return nil, false, fmt.Errorf("GitHub API returned %d: %s", resp.StatusCode, string(body))
	}

	var issues []Issue
	if decodeErr := json.NewDecoder(resp.Body).Decode(&issues); decodeErr != nil {
		return nil, false, fmt.Errorf("decoding issues: %w", decodeErr)
	}

	hasMore := len(issues) == perPage

	return issues, hasMore, nil
}

type repoTask struct {
	repo string
}

type repoResult struct {
	repo          string
	skip          bool
	skipReason    string
	metadata      repoMetadata
	configContent string
	err           error
}

type repoMetadata struct {
	Description     string
	AwesomeListName string
}

func (d *Discoverer) createIssues(ctx context.Context, repos []string, existingIssues map[string]bool) error {
	// Create work channel and results channel
	tasks := make(chan repoTask, len(repos))
	results := make(chan repoResult, len(repos))

	// Start worker pool
	var wg sync.WaitGroup
	for range d.config.Workers {
		wg.Add(1)

		go d.processRepoWorker(ctx, tasks, results, existingIssues, &wg)
	}

	// Send tasks to workers
	for _, repo := range repos {
		tasks <- repoTask{repo: repo}
	}

	close(tasks)

	// Wait for all workers to complete and close results
	go func() {
		wg.Wait()
		close(results)
	}()

	// Process results
	for result := range results {
		if result.skip {
			fmt.Printf("%s\n", result.skipReason)
			continue
		}

		if result.err != nil {
			fmt.Printf("❌ Failed to process %s: %v\n", result.repo, result.err)
			continue
		}

		// Create issue
		issueBody := d.buildIssueBody(
			result.repo,
			result.metadata.AwesomeListName,
			result.metadata.Description,
			result.configContent,
		)

		if d.config.DryRun {
			fmt.Printf("📝 [DRY RUN] Would create issue for %s\n", result.repo)
			continue
		}

		if err := d.createIssue(ctx, &NewIssue{
			Title:  fmt.Sprintf("Auto-Discovery: %s", result.repo),
			Body:   issueBody,
			Labels: []string{"auto-discovery", "needs-review"},
		}); err != nil {
			fmt.Printf("❌ Failed to create issue for %s: %v\n", result.repo, err)
			continue
		}

		fmt.Printf("📝 Created issue for %s\n", result.repo)
	}

	return nil
}

func (d *Discoverer) processRepoWorker(
	ctx context.Context,
	tasks <-chan repoTask,
	results chan<- repoResult,
	existingIssues map[string]bool,
	wg *sync.WaitGroup,
) {
	defer wg.Done()

	for task := range tasks {
		repo := task.repo

		if existingIssues[repo] {
			results <- repoResult{
				repo:       repo,
				skip:       true,
				skipReason: fmt.Sprintf("⏭️  Issue already exists for %s", repo),
			}

			continue
		}

		// Rate limit API calls
		<-d.rateLimiter.C

		// Verify README.json exists
		readmeURL := fmt.Sprintf("https://raw.githubusercontent.com/%s/main/README.json", repo)
		if !d.fileExists(ctx, readmeURL) {
			results <- repoResult{
				repo:       repo,
				skip:       true,
				skipReason: fmt.Sprintf("⚠️  Skipping %s (README.json not found)", repo),
			}

			continue
		}

		// Fetch .enhansome.jsonc content
		<-d.rateLimiter.C

		configContent, err := d.fetchFileContent(ctx, repo, ".enhansome.jsonc")
		if err != nil {
			fmt.Printf("⚠️  Warning: Could not fetch .enhansome.jsonc for %s: %v\n", repo, err)

			configContent = "{}"
		}

		// Fetch README.json metadata
		<-d.rateLimiter.C

		readmeContent, err := d.fetchFileContent(ctx, repo, "README.json")
		if err != nil {
			fmt.Printf("⚠️  Warning: Could not fetch README.json for %s: %v\n", repo, err)

			readmeContent = "{}"
		}

		var metadata struct {
			Metadata struct {
				Description     string `json:"description"`
				AwesomeListName string `json:"awesome_list_name"`
			} `json:"metadata"`
		}

		_ = json.Unmarshal([]byte(readmeContent), &metadata)

		results <- repoResult{
			repo: repo,
			metadata: repoMetadata{
				Description:     metadata.Metadata.Description,
				AwesomeListName: metadata.Metadata.AwesomeListName,
			},
			configContent: configContent,
		}
	}
}

func (d *Discoverer) fileExists(ctx context.Context, url string) bool {
	req, err := http.NewRequestWithContext(ctx, http.MethodHead, url, nil)
	if err != nil {
		return false
	}

	resp, err := d.httpClient.Do(req)
	if err != nil {
		return false
	}
	defer resp.Body.Close()

	return resp.StatusCode == http.StatusOK
}

func (d *Discoverer) fetchFileContent(ctx context.Context, repo, path string) (string, error) {
	url := fmt.Sprintf("https://raw.githubusercontent.com/%s/main/%s", repo, path)

	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return "", fmt.Errorf("creating file request: %w", err)
	}

	resp, err := d.httpClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("executing file request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("status %d", resp.StatusCode)
	}

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return "", fmt.Errorf("reading response body: %w", err)
	}

	return string(body), nil
}

func (d *Discoverer) buildIssueBody(repo, awesomeListName, description, configContent string) string {
	if awesomeListName == "" {
		awesomeListName = "Unknown"
	}

	if description == "" {
		description = "No description available"
	}

	return fmt.Sprintf(`## Auto-Discovery: %s

A new repository with Enhansome configuration has been discovered!

### Repository Information
- **Repository:** https://github.com/%s
- **Awesome List Name:** %s
- **Description:** %s
- **README.json:** [View file](https://github.com/%s/blob/main/README.json)
- **Configuration:** [View .enhansome.jsonc](https://github.com/%s/blob/main/.enhansome.jsonc)

### Configuration Preview
`+"```jsonc"+`
%s
`+"```"+`

### Action Required
Please review this repository and decide:

1. **✅ Approve:** Add `+"`%s/README.json`"+` to `+"`allowlist.txt`"+`
2. **❌ Reject:** Add `+"`%s`"+` to `+"`denylist.txt`"+`
3. **⏸️  Defer:** Close this issue to review later

See [MAINTAINING.md](./MAINTAINING.md) for detailed instructions.

---
*This issue was automatically created by the auto-discovery workflow.*`,
		repo, repo, awesomeListName, description, repo, repo, configContent, repo, repo)
}

func (d *Discoverer) createIssue(ctx context.Context, issue *NewIssue) error {
	url := fmt.Sprintf("https://api.github.com/repos/%s/issues", d.config.Repository)

	body, err := json.Marshal(issue)
	if err != nil {
		return fmt.Errorf("marshaling issue: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, strings.NewReader(string(body)))
	if err != nil {
		return fmt.Errorf("creating issue request: %w", err)
	}

	req.Header.Set("Authorization", "token "+d.config.Token)
	req.Header.Set("Accept", "application/vnd.github.v3+json")
	req.Header.Set("Content-Type", "application/json")

	resp, err := d.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("executing issue request: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusCreated {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("GitHub API returned %d: %s", resp.StatusCode, string(respBody))
	}

	return nil
}
