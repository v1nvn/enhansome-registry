# Auto-Discovery Script

This Go application automatically discovers repositories with Enhansome configuration and creates review issues.

## Features

- ✅ Fully testable Go code with BDD-style tests
- ✅ **Parallel processing** with configurable worker pool
- ✅ **Rate limiting** to prevent API throttling
- ✅ GitHub API integration
- ✅ Allowlist/denylist filtering
- ✅ Duplicate issue detection
- ✅ README.json validation
- ✅ Dry-run mode for testing
- ✅ Comprehensive concurrency tests with race detector

## Usage

### In GitHub Actions

The workflow automatically runs this script weekly. See `.github/workflows/auto-discover.yaml`.

### Local Testing

```bash
# Run tests
go test -v

# Run with dry-run mode (doesn't create issues)
export GITHUB_TOKEN=your_token_here
export GITHUB_REPOSITORY=owner/repo

go run . \
  -allowlist ../../allowlist.txt \
  -denylist ../../denylist.txt \
  -dry-run

# Run for real (creates issues)
go run . \
  -allowlist ../../allowlist.txt \
  -denylist ../../denylist.txt
```

### Command-line Flags

- `-token` - GitHub token (default: `$GITHUB_TOKEN`)
- `-repo` - Repository in `owner/repo` format (default: `$GITHUB_REPOSITORY`)
- `-allowlist` - Path to allowlist file (default: `allowlist.txt`)
- `-denylist` - Path to denylist file (default: `denylist.txt`)
- `-workers` - Number of parallel workers (default: `5`)
- `-dry-run` - Don't actually create issues, just show what would be done

## Testing

This project uses [Ginkgo v2](https://github.com/onsi/ginkgo) with [Gomega](https://github.com/onsi/gomega) for BDD-style testing.

```bash
# Run all tests (including BDD tests)
go test -v

# Run tests with race detector (IMPORTANT for concurrency)
go test -v -race

# Run Ginkgo BDD tests with verbose output
ginkgo -v

# Run tests with coverage
go test -v -race -coverprofile=coverage.out
go tool cover -html=coverage.out

# Run specific test
go test -v -run TestFilterRepositories
```

For detailed testing documentation, see [TESTING.md](./TESTING.md).

## Architecture

### Files

- `main.go` - Entry point, CLI argument parsing
- `discoverer.go` - Core discovery logic with parallel processing
- `discoverer_test.go` - Traditional unit tests
- `discoverer_concurrency_test.go` - BDD-style concurrency tests
- `discoverer_suite_test.go` - Ginkgo test suite configuration
- `TESTING.md` - Comprehensive testing documentation

### Flow

1. **Load Lists**: Read allowlist and denylist files
2. **Search**: Query GitHub API for repos with `.enhansome.jsonc`
3. **Filter**: Remove repos already in allowlist or denylist
4. **Check Issues**: Get existing auto-discovery issues
5. **Process in Parallel**: Use worker pool to validate repos concurrently
   - Worker pool (default: 5 workers)
   - Rate limiting (10 requests/second)
   - Verify README.json exists for each repo
   - Fetch .enhansome.jsonc and README.json metadata
6. **Create Issues**: Generate formatted issues for review

### Parallel Processing Architecture

The script uses a **worker pool pattern** for efficient parallel processing:

- **Worker Pool**: Fixed number of goroutines (configurable via `-workers` flag)
- **Task Queue**: Buffered channel for distributing work
- **Results Collection**: Separate channel for gathering results
- **Rate Limiting**: `time.Ticker` ensures we don't exceed GitHub API limits (10 req/sec)
- **Thread Safety**: Read-only access to shared maps, safe HTTP client usage

## Why Go?

- **Testability**: Easy to write unit tests with table-driven tests
- **Type Safety**: Catch errors at compile time
- **Performance**: Fast execution, compiled binary
- **Single Binary**: No runtime dependencies
- **GitHub Actions**: Native support with `actions/setup-go`
- **Standard Library**: HTTP client, JSON parsing built-in

## Development

```bash
# Format code
go fmt ./...

# Lint (requires golangci-lint)
golangci-lint run

# Build binary
go build -o auto-discover

# Run binary
./auto-discover -dry-run
```
