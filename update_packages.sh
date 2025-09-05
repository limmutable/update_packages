#!/opt/homebrew/bin/bash

# update_packages.sh — Beautiful package updater for brew, uv, and pip
# Features:
# - Pretty, consistent CLI output with colors and emojis
# - Robust error handling and clear failure messages
# - Optional flags: --dry-run, --only=brew|uv|pip, --no-color, --quiet
# - Section timing and concise summary

set -Eeuo pipefail
IFS=$'\n\t'

START_TIME=$(date +%s)
SCRIPT_NAME=$(basename "$0")

# -----------------------------
# Color and formatting handling
# -----------------------------
COLOR=true
QUIET=false
DRY_RUN=false
ONLY=""

supports_color() {
  # Respect NO_COLOR (https://no-color.org/)
  if [[ -n "${NO_COLOR:-}" ]]; then return 1; fi
  # stdout is a terminal and tput supports colors
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1; then
    local colors
    colors=$(tput colors 2>/dev/null || echo 0)
    [[ ${colors} -ge 8 ]]
    return $?
  fi
  return 1
}

# Defaults, may be disabled by --no-color or missing capability
if supports_color; then
  BOLD="\033[1m"; DIM="\033[2m"; RESET="\033[0m"
  FG_RED="\033[31m"; FG_GREEN="\033[32m"; FG_YELLOW="\033[33m"; FG_BLUE="\033[34m"; FG_CYAN="\033[36m"; FG_MAGENTA="\033[35m"
else
  COLOR=false
  BOLD=""; DIM=""; RESET=""; FG_RED=""; FG_GREEN=""; FG_YELLOW=""; FG_BLUE=""; FG_CYAN=""; FG_MAGENTA=""
fi

# -----------------------------
# CLI argument parsing
# -----------------------------
usage() {
  cat <<EOF
${SCRIPT_NAME} — Update Homebrew, uv, and pip with pretty output

Usage: ${SCRIPT_NAME} [options]

Options:
  --dry-run            Print what would run, but don't execute
  --only=<section>     Only run one section: brew | uv | pip
  --no-color           Disable colored output
  --quiet              Reduce output (errors and summary only)
  -h, --help           Show this help
EOF
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --no-color) COLOR=false; BOLD=""; DIM=""; RESET=""; FG_RED=""; FG_GREEN=""; FG_YELLOW=""; FG_BLUE=""; FG_CYAN=""; FG_MAGENTA="" ;;
    --quiet) QUIET=true ;;
    --only=*) ONLY="${arg#*=}" ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; usage; exit 2 ;;
  esac
done

# -----------------------------
# Logging helpers
# -----------------------------
print() { $QUIET && return 0; printf "%b\n" "$1"; }
msg()   { print "$1"; }

header()   { $QUIET && return 0; printf "%b\n" "${BOLD}${FG_BLUE}🔄 ${1}${RESET}"; printf "%b\n" "${DIM}$(printf '%.0s=' {1..38})${RESET}"; }
section()  { $QUIET && return 0; printf "%b\n" "${BOLD}${FG_MAGENTA}${1}${RESET}"; printf "%b\n" "${DIM}$(printf '%.0s-' {1..38})${RESET}"; }
info()     { $QUIET && return 0; printf "%b\n" "${FG_CYAN}ℹ️  ${1}${RESET}"; }
success()  { printf "%b\n" "${FG_GREEN}✅ ${1}${RESET}"; }
warn()     { printf "%b\n" "${FG_YELLOW}⚠️  ${1}${RESET}"; }
error()    { printf "%b\n" "${FG_RED}❌ ${1}${RESET}"; }

run_cmd() {
  # Arguments: <label> <command...>
  local label="$1"; shift
  local cmd_str
  printf -v cmd_str "%q " "$@"
  $QUIET || printf "%b" "${DIM}› ${label}...${RESET}\r"
  if $DRY_RUN; then
    $QUIET || printf "%b\n" "${DIM}› ${label}: ${BOLD}(dry-run)${RESET}"
    $QUIET || printf "%b\n" "${DIM}  ${cmd_str}${RESET}"
    return 0
  fi
  if "$@" >/dev/null 2>&1; then
    $QUIET || printf "%b\n" "${FG_GREEN}✓ ${label}${RESET}"
    return 0
  else
    local ec=$?
    printf "\r"  # clear carriage
    error "$label (exit $ec)"
    printf "%b\n" "${DIM}${cmd_str}${RESET}"
    return $ec
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

timer_start() { date +%s; }
# shellcheck disable=SC2120
elapsed() {
  local start=$1
  local end; end=$(date +%s)
  echo $(( end - start ))
}

# -----------------------------
# Spinner and progress functions
# -----------------------------
SPINNER_PID=""
SPINNER_CHARS=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")

start_spinner() {
  local msg="${1:-Working}"
  if $QUIET || $DRY_RUN; then return 0; fi
  
  (
    i=0
    while true; do
      printf "\r%b" "${DIM}${SPINNER_CHARS[$i]} ${msg}...${RESET}"
      i=$(( (i + 1) % ${#SPINNER_CHARS[@]} ))
      sleep 0.1
    done
  ) &
  SPINNER_PID=$!
}

stop_spinner() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill $SPINNER_PID 2>/dev/null || true
    wait $SPINNER_PID 2>/dev/null || true
    SPINNER_PID=""
    printf "\r%*s\r" 80 ""  # Clear line
  fi
}

run_cmd_with_spinner() {
  # Arguments: <label> <command...>
  local label="$1"; shift
  local cmd_str
  printf -v cmd_str "%q " "$@"
  
  if $DRY_RUN; then
    $QUIET || printf "%b\n" "${DIM}› ${label}: ${BOLD}(dry-run)${RESET}"
    $QUIET || printf "%b\n" "${DIM}  ${cmd_str}${RESET}"
    return 0
  fi
  
  start_spinner "$label"
  if "$@" >/dev/null 2>&1; then
    stop_spinner
    $QUIET || printf "%b\n" "${FG_GREEN}✓ ${label}${RESET}"
    return 0
  else
    local ec=$?
    stop_spinner
    error "$label (exit $ec)"
    printf "%b\n" "${DIM}${cmd_str}${RESET}"
    return $ec
  fi
}

# Count packages that need updating
count_brew_outdated() {
  if command_exists brew; then
    brew outdated --formula 2>/dev/null | wc -l | tr -d ' ' || echo "0"
  else
    echo "0"
  fi
}

count_brew_casks_outdated() {
  if command_exists brew; then
    brew outdated --cask 2>/dev/null | wc -l | tr -d ' ' || echo "0"
  else
    echo "0"
  fi
}

count_uv_tools_outdated() {
  if command_exists uv; then
    # Check if any tools need updating
    local output
    output=$(uv tool list --outdated 2>/dev/null || echo "")
    if [[ -n "$output" ]]; then
      echo "$output" | grep -c "^-" || echo "0"
    else
      echo "0"
    fi
  else
    echo "0"
  fi
}

count_pip_outdated() {
  if command_exists pip; then
    pip list --outdated --format=json 2>/dev/null | python -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# Get tool versions
get_brew_version() {
  if command_exists brew; then
    brew --version 2>/dev/null | head -n1 | sed 's/Homebrew //' | cut -d' ' -f1 || echo "unknown"
  else
    echo "N/A"
  fi
}

get_uv_version() {
  if command_exists uv; then
    uv --version 2>/dev/null | sed 's/uv //' | cut -d' ' -f1 || echo "unknown"
  else
    echo "N/A"
  fi
}

get_pip_version() {
  if command_exists pip; then
    pip --version 2>/dev/null | cut -d' ' -f2 || echo "unknown"
  else
    echo "N/A"
  fi
}

# -----------------------------
# Error trap
# -----------------------------
trap 'ec=$?; if [[ $ec -ne 0 ]]; then error "Failed with exit code $ec"; fi' EXIT

# -----------------------------
# Begin
# -----------------------------
header "Starting package update process"

# Track which sections run
RAN_BREW=false
RAN_UV=false
RAN_PIP=false

# -----------------------------
# Homebrew
# -----------------------------
if [[ -z "$ONLY" || "$ONLY" == "brew" ]]; then
  section "📦 Homebrew"
  if command_exists brew; then
    RAN_BREW=true
    s=$(timer_start)
    
    # Update brew itself
    run_cmd_with_spinner "brew update" brew update
    
    # Check for outdated packages
    if ! $DRY_RUN; then
      info "Checking for outdated packages..."
      outdated_formulas=$(count_brew_outdated)
      outdated_casks=$(count_brew_casks_outdated)
      total_outdated=$((outdated_formulas + outdated_casks))
      
      if [[ $total_outdated -gt 0 ]]; then
        info "Found $outdated_formulas formula(s) and $outdated_casks cask(s) to update"
        run_cmd_with_spinner "brew upgrade ($total_outdated package(s))" brew upgrade
      else
        info "All packages are up to date"
      fi
    else
      run_cmd "brew upgrade" brew upgrade
    fi
    
    run_cmd_with_spinner "brew cleanup" brew cleanup
    
    if ! $DRY_RUN; then
      if brew doctor >/dev/null 2>&1; then
        success "brew doctor: no critical issues"
      else
        warn "brew doctor reported issues (often normal in dev setups)"
      fi
    else
      info "brew doctor (skipped in dry-run)"
    fi
    info "Completed in $(elapsed "$s")s"
  else
    warn "Homebrew not found. Skipping."
  fi
fi

# -----------------------------
# uv (Python toolchain manager)
# -----------------------------
if [[ -z "$ONLY" || "$ONLY" == "uv" ]]; then
  section "🐍 uv"
  if command_exists uv; then
    RAN_UV=true
    s=$(timer_start)
    # Try self-update; tolerate failure if installed via brew
    if ! $DRY_RUN; then
      if uv self update >/dev/null 2>&1; then
        success "uv self-updated"
      else
        info "uv self-update skipped (possibly managed by Homebrew)"
      fi
    else
      info "uv self update (skipped in dry-run)"
    fi

    # Project or global tools
    if [[ -f "pyproject.toml" ]]; then
      if $DRY_RUN; then
        info "Would run: uv sync --upgrade (project deps)"
      else
        # Count outdated dependencies if possible
        info "Checking project dependencies..."
        run_cmd_with_spinner "uv sync --upgrade" uv sync --upgrade
      fi
    else
      info "No pyproject.toml here; checking uv tools"
      if ! $DRY_RUN; then
        if uv tool list >/dev/null 2>&1; then
          # Check for outdated tools
          outdated_tools=$(count_uv_tools_outdated)
          if [[ $outdated_tools -gt 0 ]]; then
            info "Found $outdated_tools tool(s) to update"
            run_cmd_with_spinner "uv tool upgrade --all ($outdated_tools tool(s))" uv tool upgrade --all
          else
            info "All uv tools are up to date"
          fi
        else
          info "No global uv tools installed"
        fi
      else
        info "Would run: uv tool upgrade --all (if tools exist)"
      fi
    fi
    info "Completed in $(elapsed "$s")s"
  else
    warn "uv not found. Skipping."
  fi
fi

# -----------------------------
# pip
# -----------------------------
if [[ -z "$ONLY" || "$ONLY" == "pip" ]]; then
  section "🐍 pip"
  if command_exists pip; then
    RAN_PIP=true
    s=$(timer_start)
    if $DRY_RUN; then
      info "Would run: python -m pip install --upgrade pip"
    else
      run_cmd_with_spinner "upgrade pip itself" python -m pip install --upgrade pip
    fi

    # Upgrade all outdated packages
    if $DRY_RUN; then
      info "Would check: pip list --outdated --format=json and upgrade each"
    else
      info "Checking for outdated pip packages..."
      
      # Count outdated packages first
      outdated_count=$(count_pip_outdated)
      
      if [[ $outdated_count -gt 0 ]]; then
        info "Found $outdated_count package(s) to update"
        
        # Get the list of outdated packages
        mapfile -t outdated < <(pip list --outdated --format=json 2>/dev/null | python -c "import json,sys; data=json.load(sys.stdin); print('\n'.join(p['name'] for p in data) if data else '')" 2>/dev/null || true)
        
        # Filter out empty strings
        outdated=("${outdated[@]//}")
        outdated=("${outdated[@]// /}")
        
        # Update each package with progress indicator
        current=0
        for pkg in "${outdated[@]}"; do
          if [[ -n "$pkg" ]]; then
            current=$((current + 1))
            run_cmd_with_spinner "pip install -U ${pkg} ($current/$outdated_count)" pip install -U "$pkg"
          fi
        done
        success "pip packages updated ($outdated_count upgraded)"
      else
        info "All pip packages are up to date"
      fi
    fi
    info "Completed in $(elapsed "$s")s"
  else
    warn "pip not found. Skipping."
  fi
fi

# -----------------------------
# Summary
# -----------------------------
TOTAL_TIME=$(( $(date +%s) - START_TIME ))
section "📊 Summary"

# Get versions for all tools
brew_version=$(get_brew_version)
uv_version=$(get_uv_version)
pip_version=$(get_pip_version)

# Get package counts
$RAN_BREW && brew_formulas=$(command -v brew >/dev/null 2>&1 && brew list --formula 2>/dev/null | wc -l | tr -d ' ' || echo 0) || brew_formulas=0
$RAN_BREW && brew_casks=$(command -v brew >/dev/null 2>&1 && brew list --cask 2>/dev/null | wc -l | tr -d ' ' || echo 0) || brew_casks=0
$RAN_PIP && pip_count=$(command -v pip >/dev/null 2>&1 && pip list 2>/dev/null | wc -l | tr -d ' ' || echo 0) || pip_count=0

# Display summary with versions
if command_exists uv; then
  uv_tools_count=$(uv tool list 2>/dev/null | wc -l | tr -d ' ' || echo 0)
else
  uv_tools_count=0
fi
$QUIET || printf "%b\n" "- Brew (v${brew_version}): ${brew_formulas} formulas, ${brew_casks} casks"
$QUIET || printf "%b\n" "- uv (v${uv_version}): ${uv_tools_count} tools"
$QUIET || printf "%b\n" "- pip (v${pip_version}): ${pip_count} packages"

success "🎉 All requested updates completed in ${TOTAL_TIME}s${DRY_RUN:+ (dry-run)}"
