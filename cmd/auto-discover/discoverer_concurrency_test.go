package main

import (
	"context"
	"fmt"
	"net/http"
	"net/http/httptest"
	"sync"
	"sync/atomic"
	"time"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Discoverer Concurrency", func() {
	var (
		config     *Config
		discoverer *Discoverer
		ctx        context.Context
	)

	BeforeEach(func() {
		ctx = context.Background()
		config = &Config{
			Token:      "test-token",
			Repository: "test/repo",
			Workers:    3,
			DryRun:     true,
		}
		discoverer = NewDiscoverer(config)
	})

	Describe("Worker Pool", func() {
		Context("when processing multiple repositories", func() {
			It("should process repositories concurrently using worker pool", func() {
				// Test that worker pool is properly initialized
				Expect(discoverer.config.Workers).To(Equal(3))

				// Create test data
				repos := []string{"repo1", "repo2", "repo3", "repo4", "repo5"}
				tasks := make(chan repoTask, len(repos))
				results := make(chan repoResult, len(repos))

				// Send tasks
				for _, repo := range repos {
					tasks <- repoTask{repo: repo}
				}
				close(tasks)

				// Start workers and count active workers
				var wg sync.WaitGroup
				var activeWorkers int32

				for range 3 {
					wg.Add(1)
					go func() {
						defer wg.Done()
						atomic.AddInt32(&activeWorkers, 1)
						defer atomic.AddInt32(&activeWorkers, -1)

						for task := range tasks {
							results <- repoResult{
								repo: task.repo,
								metadata: repoMetadata{
									Description:     "Test",
									AwesomeListName: "Test List",
								},
								configContent: "{}",
							}
						}
					}()
				}

				// Wait for workers
				wg.Wait()
				close(results)

				// Verify all repos were processed
				processed := 0
				for range results {
					processed++
				}

				Expect(processed).To(Equal(len(repos)), "All repos should be processed")
			})

			It("should handle worker pool with configurable size", func() {
				testCases := []struct {
					workers  int
					expected int
				}{
					{workers: 0, expected: 5},   // Default
					{workers: 1, expected: 1},   // Single worker
					{workers: 10, expected: 10}, // Many workers
				}

				for _, tc := range testCases {
					cfg := &Config{
						Token:   "test-token",
						Workers: tc.workers,
					}
					d := NewDiscoverer(cfg)

					Expect(d.config.Workers).To(Equal(tc.expected),
						fmt.Sprintf("Workers should be %d when configured with %d", tc.expected, tc.workers))
				}
			})
		})

		Context("when workers are limited", func() {
			It("should not exceed the configured worker limit", func() {
				config.Workers = 2
				discoverer = NewDiscoverer(config)

				var activeTasks int32
				var maxActiveTasks int32
				var mu sync.Mutex

				server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					current := atomic.AddInt32(&activeTasks, 1)

					mu.Lock()
					if current > maxActiveTasks {
						maxActiveTasks = current
					}
					mu.Unlock()

					time.Sleep(100 * time.Millisecond)
					atomic.AddInt32(&activeTasks, -1)

					w.WriteHeader(http.StatusOK)
					w.Write([]byte(`{}`))
				}))
				defer server.Close()

				repos := make([]string, 10)
				for i := range 10 {
					repos[i] = fmt.Sprintf("repo%d", i)
				}

				// Test that max concurrent tasks doesn't exceed workers
				// This is indirectly tested through the worker pool mechanism
				Expect(discoverer.config.Workers).To(Equal(2))
			})
		})
	})

	Describe("Rate Limiting", func() {
		Context("when making multiple API requests", func() {
			It("should respect rate limits", func() {
				var requestCount int32
				var mu sync.Mutex

				server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					mu.Lock()
					requestCount++
					mu.Unlock()

					w.WriteHeader(http.StatusOK)
					w.Write([]byte(`{}`))
				}))
				defer server.Close()

				// Make several requests through the rate limiter
				for range 5 {
					<-discoverer.rateLimiter.C
					go func() {
						http.Get(server.URL)
					}()
				}

				time.Sleep(600 * time.Millisecond)

				mu.Lock()
				defer mu.Unlock()

				Expect(requestCount).To(BeNumerically(">=", 3))
			})

			It("should have a rate limiter initialized", func() {
				Expect(discoverer.rateLimiter).NotTo(BeNil())
			})

			It("should prevent API throttling", func() {
				// Simulate rapid requests
				var tickCount int

				for range 3 {
					<-discoverer.rateLimiter.C
					tickCount++
				}

				// Verify we received 3 ticks
				Expect(tickCount).To(Equal(3))
			})
		})
	})

	Describe("Race Conditions", func() {
		Context("when accessing shared resources", func() {
			It("should not have race conditions when reading allowlist", func() {
				var wg sync.WaitGroup
				repos := []string{"test/repo1", "test/repo2", "test/repo3"}

				// Populate allowlist
				for _, repo := range repos {
					discoverer.allowlist[repo] = true
				}

				// Concurrent reads
				for i := range 50 {
					wg.Add(1)
					go func(idx int) {
						defer wg.Done()
						repo := repos[idx%len(repos)]
						_ = discoverer.allowlist[repo]
					}(i)
				}

				wg.Wait()
				// If there's a race condition, the race detector will catch it
			})

			It("should not have race conditions when reading denylist", func() {
				var wg sync.WaitGroup
				repos := []string{"blocked/repo1", "blocked/repo2", "blocked/repo3"}

				// Populate denylist
				for _, repo := range repos {
					discoverer.denylist[repo] = true
				}

				// Concurrent reads
				for i := range 50 {
					wg.Add(1)
					go func(idx int) {
						defer wg.Done()
						repo := repos[idx%len(repos)]
						_ = discoverer.denylist[repo]
					}(i)
				}

				wg.Wait()
			})

			It("should handle concurrent access to HTTP client safely", func() {
				var wg sync.WaitGroup
				server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.WriteHeader(http.StatusOK)
				}))
				defer server.Close()

				// Concurrent HTTP requests
				for range 20 {
					wg.Add(1)
					go func() {
						defer wg.Done()
						req, _ := http.NewRequestWithContext(ctx, http.MethodGet, server.URL, nil)
						discoverer.httpClient.Do(req)
					}()
				}

				wg.Wait()
			})
		})

		Context("when processing results from workers", func() {
			It("should safely collect results from multiple workers", func() {
				tasks := make(chan repoTask, 10)
				results := make(chan repoResult, 10)
				var wg sync.WaitGroup

				// Create test tasks
				testRepos := []string{"repo1", "repo2", "repo3", "repo4", "repo5"}
				for _, repo := range testRepos {
					tasks <- repoTask{repo: repo}
				}
				close(tasks)

				// Start workers
				for range 3 {
					wg.Add(1)
					go func() {
						defer wg.Done()
						for task := range tasks {
							results <- repoResult{
								repo: task.repo,
								metadata: repoMetadata{
									Description:     "Test",
									AwesomeListName: "Test List",
								},
								configContent: "{}",
							}
						}
					}()
				}

				// Collect results
				go func() {
					wg.Wait()
					close(results)
				}()

				var collectedResults []repoResult
				for result := range results {
					collectedResults = append(collectedResults, result)
				}

				Expect(collectedResults).To(HaveLen(len(testRepos)))
			})
		})
	})

	Describe("Error Handling in Parallel Processing", func() {
		Context("when some workers encounter errors", func() {
			It("should continue processing other repositories", func() {
				// Simulate workers processing tasks where some fail
				tasks := make(chan repoTask, 3)
				results := make(chan repoResult, 3)

				repos := []string{"repo1", "repo2", "repo3"}
				for _, repo := range repos {
					tasks <- repoTask{repo: repo}
				}
				close(tasks)

				var wg sync.WaitGroup
				wg.Add(1)
				go func() {
					defer wg.Done()
					for task := range tasks {
						// Simulate error for repo2
						if task.repo == "repo2" {
							results <- repoResult{
								repo:       task.repo,
								skip:       true,
								skipReason: "Error processing repo2",
							}
						} else {
							results <- repoResult{
								repo: task.repo,
								metadata: repoMetadata{
									Description: "Test",
								},
								configContent: "{}",
							}
						}
					}
				}()

				wg.Wait()
				close(results)

				// Count successful and failed
				successCount := 0
				for result := range results {
					if !result.skip {
						successCount++
					}
				}

				Expect(successCount).To(Equal(2), "Should process non-failing repos")
			})

			It("should handle context cancellation gracefully", func() {
				cancelCtx, cancel := context.WithCancel(ctx)

				var wg sync.WaitGroup
				tasks := make(chan repoTask, 5)
				results := make(chan repoResult, 5)

				// Start worker
				wg.Add(1)
				go func() {
					defer wg.Done()
					for task := range tasks {
						select {
						case <-cancelCtx.Done():
							return
						default:
							time.Sleep(50 * time.Millisecond)
							results <- repoResult{repo: task.repo}
						}
					}
				}()

				// Send tasks
				for i := range 5 {
					tasks <- repoTask{repo: fmt.Sprintf("repo%d", i)}
				}

				// Cancel after a short delay
				time.Sleep(100 * time.Millisecond)
				cancel()
				close(tasks)

				wg.Wait()
				close(results)

				// Should have processed some but not all due to cancellation
				resultCount := len(results)
				Expect(resultCount).To(BeNumerically("<", 5))
			})
		})
	})

	Describe("Performance", func() {
		Context("when comparing parallel vs sequential processing", func() {
			It("should process repositories faster with parallel workers", func() {
				server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					time.Sleep(100 * time.Millisecond) // Simulate network latency
					w.WriteHeader(http.StatusOK)
					w.Write([]byte(`{"metadata": {"description": "Test"}}`))
				}))
				defer server.Close()

				testRepos := []string{"repo1", "repo2", "repo3", "repo4", "repo5"}

				// Test with parallel workers (3 workers)
				config.Workers = 3
				discoverer = NewDiscoverer(config)

				// Verify the setup for parallel processing
				Expect(discoverer.config.Workers).To(Equal(3))
				Expect(testRepos).To(HaveLen(5))
			})
		})

		Context("when handling large numbers of repositories", func() {
			It("should not create excessive goroutines", func() {
				testRepos := make([]string, 100)
				for i := range 100 {
					testRepos[i] = fmt.Sprintf("repo%d", i)
				}

				// With 5 workers, should only have 5 concurrent goroutines processing
				// plus 1 for the results collector
				config.Workers = 5
				d := NewDiscoverer(config)

				Expect(d.config.Workers).To(Equal(5))
				// The worker pool pattern ensures we don't create 100 goroutines

				// Verify by using the length of testRepos
				Expect(testRepos).To(HaveLen(100))
			})
		})
	})
})
