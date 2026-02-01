#!/bin/bash
# scripts/indexer.sh
# Build and index awesome list data from allowlist
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/entry.sh"
source "$SCRIPT_DIR/lib/validation.sh"
source "$SCRIPT_DIR/lib/matrix.sh"

# ============================================================================
# MAIN - gh calls (NOT tested)
# ============================================================================

main() {
  local mode="${MODE:-matrix}"  # "matrix", "parse", "fetch", "aggregate"

  case "$mode" in
    matrix)
      main_matrix
      ;;
    parse)
      main_parse
      ;;
    fetch)
      main_fetch
      ;;
    aggregate)
      main_aggregate
      ;;
    *)
      echo "Error: invalid mode: $mode" >&2
      exit 1
      ;;
  esac
}

# Generate matrix JSON from allowlist.txt
main_matrix() {
  local allowlist_file="${ALLOWLIST_FILE:-allowlist.txt}"

  local json
  json=$(generate_matrix_json "$allowlist_file")
  echo "json=$json" >> "$GITHUB_OUTPUT"
  echo "Generated matrix with $(echo "$json" | jq 'length') entries"
}

# Parse target into repo, file_path, and safe_filename
main_parse() {
  local target="${TARGET:-}"

  if [[ -z "$target" ]]; then
    echo "Error: TARGET environment variable is required" >&2
    exit 1
  fi

  local repo file_path safe_filename
  repo=$(echo "$target" | cut -d/ -f1,2)
  file_path=$(echo "$target" | cut -d/ -f3-)
  safe_filename=$(parse_safe_filename "$repo")

  {
    echo "repo=$repo"
    echo "file_path=$file_path"
    echo "safe_filename=$safe_filename"
  } >> "$GITHUB_OUTPUT"

  echo "Parsed: repo=$repo, file_path=$file_path, safe_filename=$safe_filename"
}

# Fetch and validate a single data file
main_fetch() {
  local repo="${REPO:-}"
  local file_path="${FILE_PATH:-}"
  local safe_filename="${SAFE_FILENAME:-}"

  if [[ -z "$repo" ]] || [[ -z "$file_path" ]]; then
    echo "Error: REPO and FILE_PATH environment variables are required" >&2
    exit 1
  fi

  local url
  url=$(build_raw_url "$repo" "$file_path")

  echo "Fetching from $url"

  # Fetch file
  if ! curl -s -f -L -o "$safe_filename" "$url"; then
    echo "::error::Failed to fetch file from $url. The file may not exist or the repository is private."
    exit 1
  fi

  # Validate JSON
  if ! jq '.' "$safe_filename" > /dev/null 2>&1; then
    echo "::error::Validation failed: The file '$safe_filename' is not valid JSON."
    exit 1
  fi
  echo "✅ File is valid JSON."

  # Security check: ensure source_repository matches
  local source_in_file
  source_in_file=$(jq -r '.metadata.source_repository' "$safe_filename")

  if [[ "$source_in_file" != "$repo" ]]; then
    echo "::error::Validation failed: The 'source_repository' field ('$source_in_file') does not match the expected source ('$repo')."
    exit 1
  fi
  echo "✅ Security check passed."
}

# Aggregate and commit all downloaded data files
main_aggregate() {
  local temp_dir="${TEMP_DIR:-./temp-data}"
  local data_dir="${DATA_DIR:-./data}"

  # Ensure the data directory exists and is empty
  rm -rf "$data_dir"
  mkdir -p "$data_dir"

  # Move files out of artifact subdirectories
  find "$temp_dir" -type f -name "*.json" -exec mv {} "$data_dir/" \;

  echo "Data aggregation complete."
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
