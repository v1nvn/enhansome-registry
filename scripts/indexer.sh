#!/bin/bash
# scripts/indexer.sh
# Build and index awesome list data from repos/ directory structure
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/log.sh"
source "$SCRIPT_DIR/lib/dry_run.sh"
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
      log_error "Invalid mode: $mode"
      exit 1
      ;;
  esac
}

# Generate matrix JSON from repos/ directory
main_matrix() {
  local repos_dir="${REPOS_DIR:-./repos}"

  local json
  json=$(generate_matrix_from_repos "$repos_dir")
  echo "json=$json" >> "$GITHUB_OUTPUT"
  log_info "Generated matrix with $(echo "$json" | jq 'length') entries"
}

# Parse target into repo, file_path, and safe_filename
main_parse() {
  local target="${TARGET:-}"

  if [[ -z "$target" ]]; then
    log_error "TARGET environment variable is required"
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

  log_info "Parsed: repo=$repo, file_path=$file_path, safe_filename=$safe_filename"
}

# Fetch and validate a single data file
main_fetch() {
  local repo="${REPO:-}"
  local file_path="${FILE_PATH:-}"
  local safe_filename="${SAFE_FILENAME:-}"

  if [[ -z "$repo" ]] || [[ -z "$file_path" ]]; then
    log_error "REPO and FILE_PATH environment variables are required"
    exit 1
  fi

  local url
  url=$(build_raw_url "$repo" "$file_path")

  log_info "Fetching from $url"

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
  log_info "File is valid JSON"

  # Security check: ensure source_repository matches
  local source_in_file
  source_in_file=$(jq -r '.metadata.source_repository' "$safe_filename")

  if [[ "$source_in_file" != "$repo" ]]; then
    echo "::error::Validation failed: The 'source_repository' field ('$source_in_file') does not match the expected source ('$repo')."
    exit 1
  fi
  log_info "Security check passed"
}

# Aggregate and commit all downloaded data files
# For each repos/*/*/index.json, find its artifact in temp-data by safe_filename, copy to repos/<owner>/<repo>/data.json
main_aggregate() {
  local temp_dir="${TEMP_DIR:-./temp-data}"
  local repos_dir="${REPOS_DIR:-./repos}"

  # Find all index.json files and copy corresponding data files
  local relative_path owner repo
  while IFS= read -r -d '' index_file; do
    # Extract owner and repo from index file path
    relative_path="${index_file#$repos_dir/}"
    owner=$(echo "$relative_path" | cut -d/ -f1)
    repo=$(echo "$relative_path" | cut -d/ -f2)

    # Build safe filename for lookup in temp_dir
    local safe_filename="${owner}_${repo}.json"
    local source_file="$temp_dir/$safe_filename"
    local dest_file="$repos_dir/$owner/$repo/data.json"

    # Copy the data file if it exists
    if [[ -f "$source_file" ]]; then
      cp "$source_file" "$dest_file"
      log_info "Copied $safe_filename to repos/$owner/$repo/data.json"
    else
      log_warn "No data file found for $owner/$repo (expected $safe_filename)"
    fi
  done < <(find "$repos_dir" -type f -name "index.json" -print0)

  if [[ "$(is_dry_run)" == "true" ]]; then
    dry_run_log "commit data files"
  fi
  log_info "Data aggregation complete"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
