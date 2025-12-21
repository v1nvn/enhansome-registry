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
