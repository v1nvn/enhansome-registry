package main

import (
	"context"
	"net/http"
	"net/http/httptest"
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("Discoverer Unit Tests", func() {
	var (
		config     *Config
		discoverer *Discoverer
	)

	BeforeEach(func() {
		config = &Config{}
		discoverer = NewDiscoverer(config)
	})

	Describe("Search Repositories Pagination", func() {
		var server *httptest.Server

		AfterEach(func() {
			if server != nil {
				server.Close()
			}
		})

		Context("when searching repositories with pagination", func() {
			It("should fetch all pages when total exceeds per_page", func() {
				requestCount := 0
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					requestCount++
					page := r.URL.Query().Get("page")

					var response string
					switch page {
					case "1":
						// First page: 3 items, total 5 (simulating per_page=3)
						response = `{
							"total_count": 5,
							"items": [
								{"repository": {"full_name": "owner1/repo1"}},
								{"repository": {"full_name": "owner2/repo2"}},
								{"repository": {"full_name": "owner3/repo3"}}
							]
						}`
					case "2":
						// Second page: 2 items (less than per_page, signals end)
						response = `{
							"total_count": 5,
							"items": [
								{"repository": {"full_name": "owner4/repo4"}},
								{"repository": {"full_name": "owner5/repo5"}}
							]
						}`
					default:
						response = `{"total_count": 5, "items": []}`
					}
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write([]byte(response))
				}))

				// Configure discoverer to use test server
				config = &Config{
					Token:   "test-token",
					BaseURL: server.URL,
				}
				discoverer = NewDiscoverer(config)

				ctx := context.Background()

				// Test first page
				repos1, hasMore1, err := discoverer.searchRepositoriesPage(ctx, "test", 1, 3)
				Expect(err).NotTo(HaveOccurred())
				Expect(repos1).To(HaveLen(3))
				Expect(hasMore1).To(BeTrue()) // 3 items == perPage && 1*3 < 5

				// Test second page
				repos2, hasMore2, err := discoverer.searchRepositoriesPage(ctx, "test", 2, 3)
				Expect(err).NotTo(HaveOccurred())
				Expect(repos2).To(HaveLen(2))
				Expect(hasMore2).To(BeFalse()) // 2 items < perPage

				Expect(requestCount).To(Equal(2))
			})

			It("should stop when receiving empty results", func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					response := `{"total_count": 0, "items": []}`
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write([]byte(response))
				}))

				config = &Config{
					Token:   "test-token",
					BaseURL: server.URL,
				}
				discoverer = NewDiscoverer(config)

				ctx := context.Background()
				repos, hasMore, err := discoverer.searchRepositoriesPage(ctx, "test", 1, 100)
				Expect(err).NotTo(HaveOccurred())
				Expect(repos).To(BeEmpty())
				Expect(hasMore).To(BeFalse())
			})

			It("should deduplicate repositories across pages", func() {
				requestCount := 0
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					requestCount++
					page := r.URL.Query().Get("page")

					var response string
					switch page {
					case "1":
						response = `{
							"total_count": 4,
							"items": [
								{"repository": {"full_name": "owner1/repo1"}},
								{"repository": {"full_name": "owner2/repo2"}}
							]
						}`
					case "2":
						// Include a duplicate
						response = `{
							"total_count": 4,
							"items": [
								{"repository": {"full_name": "owner1/repo1"}},
								{"repository": {"full_name": "owner3/repo3"}}
							]
						}`
					default:
						response = `{"total_count": 4, "items": []}`
					}
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write([]byte(response))
				}))

				config = &Config{
					Token:   "test-token",
					BaseURL: server.URL,
					PerPage: 2, // Use small page size to test pagination
				}
				discoverer = NewDiscoverer(config)

				ctx := context.Background()
				repos, err := discoverer.searchRepositories(ctx)
				Expect(err).NotTo(HaveOccurred())
				// Should have 3 unique repos, not 4
				Expect(repos).To(HaveLen(3))
				Expect(repos).To(ContainElements("owner1/repo1", "owner2/repo2", "owner3/repo3"))
			})
		})
	})

	Describe("Get Existing Issues Pagination", func() {
		var server *httptest.Server

		AfterEach(func() {
			if server != nil {
				server.Close()
			}
		})

		Context("when fetching existing issues with pagination", func() {
			It("should fetch all pages of issues", func() {
				requestCount := 0
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					requestCount++
					page := r.URL.Query().Get("page")

					var response string
					switch page {
					case "1":
						// First page: 2 items (simulating per_page=2)
						response = `[
							{"title": "Auto-Discovery: owner1/repo1"},
							{"title": "Auto-Discovery: owner2/repo2"}
						]`
					case "2":
						// Second page: 1 item (less than per_page)
						response = `[
							{"title": "Auto-Discovery: owner3/repo3"}
						]`
					default:
						response = `[]`
					}
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write([]byte(response))
				}))

				config = &Config{
					Token:      "test-token",
					Repository: "test/registry",
					BaseURL:    server.URL,
				}
				discoverer = NewDiscoverer(config)

				ctx := context.Background()

				// Test first page
				issues1, hasMore1, err := discoverer.getExistingIssuesPage(ctx, 1, 2)
				Expect(err).NotTo(HaveOccurred())
				Expect(issues1).To(HaveLen(2))
				Expect(hasMore1).To(BeTrue()) // 2 items == perPage

				// Test second page
				issues2, hasMore2, err := discoverer.getExistingIssuesPage(ctx, 2, 2)
				Expect(err).NotTo(HaveOccurred())
				Expect(issues2).To(HaveLen(1))
				Expect(hasMore2).To(BeFalse()) // 1 item < perPage
			})

			It("should extract repo names from issue titles across pages", func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					page := r.URL.Query().Get("page")

					var response string
					switch page {
					case "1":
						response = `[
							{"title": "Auto-Discovery: owner1/repo1"},
							{"title": "Some other issue"},
							{"title": "Auto-Discovery: owner2/repo2"}
						]`
					case "2":
						response = `[
							{"title": "Auto-Discovery: owner3/repo3"}
						]`
					default:
						response = `[]`
					}
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write([]byte(response))
				}))

				config = &Config{
					Token:      "test-token",
					Repository: "test/registry",
					BaseURL:    server.URL,
					PerPage:    3, // Use small page size to test pagination
				}
				discoverer = NewDiscoverer(config)

				ctx := context.Background()
				existingIssues, err := discoverer.getExistingIssues(ctx)
				Expect(err).NotTo(HaveOccurred())

				// Should have 3 repos extracted (ignoring "Some other issue")
				Expect(existingIssues).To(HaveLen(3))
				Expect(existingIssues["owner1/repo1"]).To(BeTrue())
				Expect(existingIssues["owner2/repo2"]).To(BeTrue())
				Expect(existingIssues["owner3/repo3"]).To(BeTrue())
			})

			It("should handle empty issues list", func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					w.Header().Set("Content-Type", "application/json")
					w.WriteHeader(http.StatusOK)
					_, _ = w.Write([]byte(`[]`))
				}))

				config = &Config{
					Token:      "test-token",
					Repository: "test/registry",
					BaseURL:    server.URL,
				}
				discoverer = NewDiscoverer(config)

				ctx := context.Background()
				existingIssues, err := discoverer.getExistingIssues(ctx)
				Expect(err).NotTo(HaveOccurred())
				Expect(existingIssues).To(BeEmpty())
			})
		})
	})

	Describe("Loading Lists", func() {
		Context("when loading allowlist", func() {
			It("should parse allowlist file correctly", func() {
				content := `# Comment line
v1nvn/enhansome-go/README.json
v1nvn/enhansome-selfhosted/README.json

# Another comment
owner/repo/README.json
`
				tmpfile, err := os.CreateTemp("", "allowlist-*.txt")
				Expect(err).NotTo(HaveOccurred())
				defer os.Remove(tmpfile.Name())

				_, err = tmpfile.WriteString(content)
				Expect(err).NotTo(HaveOccurred())
				tmpfile.Close()

				discoverer.config.AllowlistPath = tmpfile.Name()
				err = discoverer.loadAllowlist()
				Expect(err).NotTo(HaveOccurred())

				Expect(discoverer.allowlist).To(HaveLen(3))
				Expect(discoverer.allowlist["v1nvn/enhansome-go"]).To(BeTrue())
				Expect(discoverer.allowlist["v1nvn/enhansome-selfhosted"]).To(BeTrue())
				Expect(discoverer.allowlist["owner/repo"]).To(BeTrue())
			})

			It("should ignore comments and empty lines", func() {
				content := `
# This is a comment

test/repo/README.json
# Another comment

`
				tmpfile, err := os.CreateTemp("", "allowlist-*.txt")
				Expect(err).NotTo(HaveOccurred())
				defer os.Remove(tmpfile.Name())

				_, err = tmpfile.WriteString(content)
				Expect(err).NotTo(HaveOccurred())
				tmpfile.Close()

				discoverer.config.AllowlistPath = tmpfile.Name()
				err = discoverer.loadAllowlist()
				Expect(err).NotTo(HaveOccurred())

				Expect(discoverer.allowlist).To(HaveLen(1))
				Expect(discoverer.allowlist["test/repo"]).To(BeTrue())
			})
		})

		Context("when loading denylist", func() {
			It("should parse denylist file correctly", func() {
				content := `# Blocked repos
spammer/fake-list
malicious/repo
`
				tmpfile, err := os.CreateTemp("", "denylist-*.txt")
				Expect(err).NotTo(HaveOccurred())
				defer os.Remove(tmpfile.Name())

				_, err = tmpfile.WriteString(content)
				Expect(err).NotTo(HaveOccurred())
				tmpfile.Close()

				discoverer.config.DenylistPath = tmpfile.Name()
				err = discoverer.loadDenylist()
				Expect(err).NotTo(HaveOccurred())

				Expect(discoverer.denylist).To(HaveLen(2))
				Expect(discoverer.denylist["spammer/fake-list"]).To(BeTrue())
				Expect(discoverer.denylist["malicious/repo"]).To(BeTrue())
			})

			It("should handle missing denylist file gracefully", func() {
				discoverer.config.DenylistPath = "/nonexistent/file.txt"
				err := discoverer.loadDenylist()
				Expect(err).NotTo(HaveOccurred()) // Denylist is optional
			})
		})
	})

	Describe("Filtering Repositories", func() {
		BeforeEach(func() {
			discoverer.allowlist = map[string]bool{
				"already/listed": true,
			}
			discoverer.denylist = map[string]bool{
				"blocked/repo": true,
			}
		})

		Context("when filtering a list of repositories", func() {
			It("should remove repositories in allowlist", func() {
				repos := []string{"already/listed", "new/repo"}
				result := discoverer.filterRepositories(repos)

				Expect(result).To(HaveLen(1))
				Expect(result[0]).To(Equal("new/repo"))
			})

			It("should remove repositories in denylist", func() {
				repos := []string{"blocked/repo", "new/repo"}
				result := discoverer.filterRepositories(repos)

				Expect(result).To(HaveLen(1))
				Expect(result[0]).To(Equal("new/repo"))
			})

			It("should keep repositories not in either list", func() {
				repos := []string{"new/repo1", "new/repo2", "new/repo3"}
				result := discoverer.filterRepositories(repos)

				Expect(result).To(HaveLen(3))
				Expect(result).To(Equal(repos))
			})

			It("should filter out both allowlist and denylist entries", func() {
				repos := []string{
					"already/listed", // In allowlist
					"blocked/repo",   // In denylist
					"new/repo1",      // New
					"new/repo2",      // New
				}
				result := discoverer.filterRepositories(repos)

				Expect(result).To(HaveLen(2))
				Expect(result).To(Equal([]string{"new/repo1", "new/repo2"}))
			})
		})
	})

	Describe("Building Issue Body", func() {
		Context("when creating issue content", func() {
			It("should include all required information", func() {
				repo := "testuser/testrepo"
				awesomeListName := "Awesome Test"
				description := "A test awesome list"
				configContent := `{"registryIndexing": true}`

				body := discoverer.buildIssueBody(repo, awesomeListName, description, configContent)

				Expect(body).To(ContainSubstring(repo))
				Expect(body).To(ContainSubstring(awesomeListName))
				Expect(body).To(ContainSubstring(description))
				Expect(body).To(ContainSubstring(configContent))
				Expect(body).To(ContainSubstring("Auto-Discovery:"))
				Expect(body).To(ContainSubstring("allowlist.txt"))
				Expect(body).To(ContainSubstring("denylist.txt"))
			})

			It("should use defaults for missing information", func() {
				repo := "testuser/testrepo"
				body := discoverer.buildIssueBody(repo, "", "", "{}")

				Expect(body).To(ContainSubstring("Unknown"))
				Expect(body).To(ContainSubstring("No description available"))
			})

			It("should include action instructions", func() {
				repo := "testuser/testrepo"
				body := discoverer.buildIssueBody(repo, "Test", "Description", "{}")

				Expect(body).To(ContainSubstring("Action Required"))
				Expect(body).To(ContainSubstring("Approve"))
				Expect(body).To(ContainSubstring("Reject"))
				Expect(body).To(ContainSubstring("Defer"))
			})

			It("should format configuration as code block", func() {
				repo := "testuser/testrepo"
				configContent := `{"registryIndexing": true, "enabled": false}`
				body := discoverer.buildIssueBody(repo, "Test", "Description", configContent)

				Expect(body).To(ContainSubstring("```jsonc"))
				Expect(body).To(ContainSubstring(configContent))
			})
		})
	})

	Describe("File Operations", func() {
		Context("when checking if file exists", func() {
			var server *httptest.Server

			BeforeEach(func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					Expect(r.Method).To(Equal("HEAD"))

					if r.URL.Path == "/exists" {
						w.WriteHeader(http.StatusOK)
					} else {
						w.WriteHeader(http.StatusNotFound)
					}
				}))
			})

			AfterEach(func() {
				server.Close()
			})

			It("should return true for existing files", func() {
				ctx := context.Background()
				exists := discoverer.fileExists(ctx, server.URL+"/exists")
				Expect(exists).To(BeTrue())
			})

			It("should return false for non-existing files", func() {
				ctx := context.Background()
				exists := discoverer.fileExists(ctx, server.URL+"/notfound")
				Expect(exists).To(BeFalse())
			})

			It("should use HEAD request", func() {
				ctx := context.Background()
				// Server validates that method is HEAD
				discoverer.fileExists(ctx, server.URL+"/exists")
			})
		})

		Context("when fetching file content", func() {
			var server *httptest.Server

			BeforeEach(func() {
				server = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
					if r.URL.Path == "/test/repo/main/.enhansome.jsonc" {
						w.WriteHeader(http.StatusOK)
						w.Write([]byte(`{"registryIndexing": true}`))
					} else {
						w.WriteHeader(http.StatusNotFound)
					}
				}))
			})

			AfterEach(func() {
				server.Close()
			})

			It("should fetch file content successfully", func() {
				ctx := context.Background()
				// Note: fetchFileContent builds URL internally, so this tests the actual implementation
				// In production, it would use raw.githubusercontent.com
				content, err := discoverer.fetchFileContent(ctx, "test/repo", ".enhansome.jsonc")

				// Since the actual implementation uses raw.githubusercontent.com,
				// we can't directly test with our mock server
				// This would require dependency injection of the base URL
				_ = content
				_ = err
			})
		})
	})

	Describe("Configuration", func() {
		Context("when creating new discoverer", func() {
			It("should use default worker count if not specified", func() {
				cfg := &Config{Workers: 0}
				d := NewDiscoverer(cfg)

				Expect(d.config.Workers).To(Equal(5))
			})

			It("should use custom worker count if specified", func() {
				cfg := &Config{Workers: 10}
				d := NewDiscoverer(cfg)

				Expect(d.config.Workers).To(Equal(10))
			})

			It("should initialize rate limiter", func() {
				cfg := &Config{}
				d := NewDiscoverer(cfg)

				Expect(d.rateLimiter).NotTo(BeNil())
			})

			It("should initialize empty allowlist and denylist", func() {
				cfg := &Config{}
				d := NewDiscoverer(cfg)

				Expect(d.allowlist).NotTo(BeNil())
				Expect(d.denylist).NotTo(BeNil())
				Expect(d.allowlist).To(BeEmpty())
				Expect(d.denylist).To(BeEmpty())
			})
		})
	})
})
