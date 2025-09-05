# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Bash script for updating package managers (Homebrew, uv, and pip) with a beautiful CLI interface. The script provides colored output, progress indicators, and robust error handling.

## Commands

### Running the script
```bash
# Run the main script
./update_packages.sh

# With options
./update_packages.sh --dry-run           # Preview what would be updated
./update_packages.sh --only=brew         # Update only Homebrew
./update_packages.sh --only=uv           # Update only uv
./update_packages.sh --only=pip          # Update only pip
./update_packages.sh --no-color          # Disable colored output
./update_packages.sh --quiet             # Reduce output (errors and summary only)
```

### Testing and development
```bash
# Make the script executable
chmod +x update_packages.sh

# Check bash syntax
bash -n update_packages.sh

# Run shellcheck for linting (if installed)
shellcheck update_packages.sh
```

## Architecture

The script is structured with clear functional sections:

1. **Configuration and argument parsing** (lines 10-73): Handles CLI flags, color support detection, and environment setup with strict error handling (`set -Eeuo pipefail`)

2. **Logging and output helpers** (lines 78-119): Provides consistent formatted output with color coding and emoji support

3. **Spinner and progress functions** (lines 124-175): Creates animated progress indicators for long-running operations

4. **Package counting functions** (lines 177-240): Determines how many packages need updating for each package manager

5. **Main update sections** (lines 257-406):
   - Homebrew section: Updates brew, upgrades outdated formulas/casks, runs cleanup and doctor
   - uv section: Self-updates uv, syncs project dependencies or updates global tools
   - pip section: Updates pip itself, then upgrades all outdated packages individually

6. **Summary generation** (lines 410-434): Collects statistics and displays final summary

## Key Implementation Details

- Uses Homebrew's bash explicitly (`#!/opt/homebrew/bin/bash`) for modern bash features
- Employs strict error handling with proper exit codes and trap handling
- Supports both terminal and non-terminal environments (respects NO_COLOR standard)
- Provides dry-run mode for testing without making changes
- Uses spinner animations for better UX during long operations
- Handles package manager availability gracefully (warns if not installed, continues with others)