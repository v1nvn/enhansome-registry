# Enhansome Registry

The official registry for Enhansome awesome lists. This repository indexes and aggregates awesome lists that have been configured with Enhansome.

## What is Enhansome?

Enhansome is a GitHub Action that transforms awesome lists into structured, searchable data. It automatically generates `README.json` files from markdown-based awesome lists.

## Getting Added to the Registry

### Using the Setup Script (Recommended)

Use the Enhansome setup script to configure your repository and create a registration PR:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/v1nvn/enhansome/main/setup.sh)"
```

This script will:
- Set up the Enhansome GitHub Action
- Create the `.enhansome.jsonc` configuration file
- Create a pull request to register your list with the registry

### Manual Registration

If you prefer manual registration:

1. Fork this repository
2. Add your repository to `allowlist.txt` in the format: `owner/repo/README.json`
3. Create a pull request

## How It Works

### Daily Indexing

Once your repository is approved:
1. The indexer workflow runs daily at 5:00 AM UTC
2. Fetches `README.json` from approved repositories
3. Validates the data format and security
4. Aggregates all data into the `/data` directory

### Data Format

Each indexed repository generates a JSON file containing:
- Metadata (description, topics, license, etc.)
- Structured awesome list categories and items
- Links to original content

### Repository Structure

```
enhansome-registry/
├── allowlist.txt           # Approved repositories
├── data/                   # Aggregated JSON data (auto-generated)
│   ├── owner_repo1.json
│   └── owner_repo2.json
├── .github/
│   └── workflows/
│       └── indexer.yaml    # Daily data aggregation
├── README.md               # This file
└── Makefile                # Build and test targets
```

## Current Registry

The registry currently indexes the following awesome lists:
- [enhansome-selfhosted](https://github.com/v1nvn/enhansome-selfhosted)
- [enhansome-go](https://github.com/v1nvn/enhansome-go)
- [enhansome-mcp-servers](https://github.com/v1nvn/enhansome-mcp-servers)
- [enhansome-ffmpeg](https://github.com/v1nvn/enhansome-ffmpeg)

## Security

### Validation Process

All indexed repositories undergo:
1. **Format validation:** Ensures valid JSON structure
2. **Security check:** Verifies `source_repository` matches expected source
3. **Content review:** Maintainer approval before indexing

## API Access

The aggregated data is available in the `/data` directory and can be accessed via GitHub's raw content URL:

```
https://raw.githubusercontent.com/v1nvn/enhansome-registry/main/data/owner_repo.json
```

## Contributing

We welcome contributions! Here's how you can help:

1. **Add Your List:** Follow the steps in "Getting Added to the Registry"
2. **Report Issues:** Found a problem? Open an issue
3. **Improve Documentation:** Submit PRs to improve this README

## License

This registry and its aggregated data are provided as-is. Individual awesome lists retain their original licenses.

## Related Projects

- [Enhansome](https://github.com/v1nvn/enhansome) - The main Enhansome GitHub Action
- [Enhansome Setup Script](https://github.com/v1nvn/enhansome/blob/main/setup.sh) - Quick setup utility

## Questions?

- **For repository owners:** Questions about getting listed? Open an issue
- **For developers:** Check out the workflow files in `.github/workflows/`
