# update_packages

An **independent shell script** that provides a beautiful and robust package updater for macOS, managing Homebrew, uv, and pip updates with style.

> **Note**: This project focuses exclusively on package management. For comprehensive shell environment setup including aliases, functions, pre-commit hooks, Python environment management, and zsh customizations, see the [dotfiles project](https://github.com/limmutable/dotfiles) - a complete development environment configuration for macOS with ARM64 optimization, UV integration, and productivity enhancements.

## Features

- **Pretty CLI output** with colors, emojis, and progress indicators
- **Smart package detection** - shows count of outdated packages before updating
- **Robust error handling** with clear failure messages
- **Flexible operation modes** - update all or specific package managers
- **Dry-run mode** for previewing changes without executing
- **Quiet mode** for CI/CD environments
- **Section timing** and comprehensive summary

## Installation

```bash
# Clone the repository
git clone https://github.com/limmutable/update_packages.git
cd update_packages

# Make the script executable
chmod +x update_packages.sh
```

## Usage

```bash
# Update all package managers
./update_packages.sh

# Preview what would be updated (dry-run)
./update_packages.sh --dry-run

# Update only specific package manager
./update_packages.sh --only=brew
./update_packages.sh --only=uv
./update_packages.sh --only=pip

# Disable colored output
./update_packages.sh --no-color

# Quiet mode (errors and summary only)
./update_packages.sh --quiet

# Show help
./update_packages.sh --help
```

## What it Updates

### Homebrew
- Updates Homebrew itself
- Upgrades outdated formulas and casks
- Runs cleanup to remove old versions
- Performs health check with `brew doctor`

### uv (Python toolchain manager)
- Self-updates uv
- Syncs project dependencies (if `pyproject.toml` exists)
- Updates global uv tools

### pip
- Updates pip itself
- Individually upgrades all outdated packages

## Requirements

- macOS with Homebrew's bash (`/opt/homebrew/bin/bash`)
- At least one of: Homebrew, uv, or pip installed
- Terminal with color support (optional, auto-detected)

## Example Output

```
🔄 Starting package update process
======================================

📦 Homebrew
--------------------------------------
✓ brew update
ℹ️  Found 3 formula(s) and 2 cask(s) to update
✓ brew upgrade (5 package(s))
✓ brew cleanup
✅ brew doctor: no critical issues
ℹ️  Completed in 45s

🐍 uv
--------------------------------------
✓ uv self-updated
✓ uv tool upgrade --all (2 tool(s))
ℹ️  Completed in 8s

🐍 pip
--------------------------------------
✓ upgrade pip itself
ℹ️  Found 4 package(s) to update
✓ pip install -U package1 (1/4)
✓ pip install -U package2 (2/4)
✓ pip install -U package3 (3/4)
✓ pip install -U package4 (4/4)
✅ pip packages updated (4 upgraded)
ℹ️  Completed in 12s

📊 Summary
--------------------------------------
- Brew (v4.4.0): 142 formulas, 28 casks
- uv (v0.4.15): 5 tools
- pip (v24.2): 87 packages
✅ 🎉 All requested updates completed in 65s
```

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

MIT - See LICENSE file for details