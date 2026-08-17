#!/bin/bash

# setup_symlinks.sh - Automate symlinking of dotfiles using GNU Stow
# Usage:
#   ./setup_symlinks.sh              → stows packages
#   ./setup_symlinks.sh --dry-run    → simulates without modifying
#   ./setup_symlinks.sh --unlink     → unstows packages
#   ./setup_symlinks.sh --help       → shows help

set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
DRY_RUN=false
UNLINK=false

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

log_info() { echo -e "${BLUE}  →${RESET} $*"; }
log_success() { echo -e "${GREEN}  ✓${RESET} $*"; }
log_error() { echo -e "${RED}  ✗${RESET} $*" >&2; }

# ── Arguments ──────────────────────────────────────────────────────────────────
for arg in "$@"; do
    case $arg in
    --dry-run)
        DRY_RUN=true
        echo -e "${YELLOW}[DRY RUN — no files will be modified]${RESET}\n"
        ;;
    --unlink)
        UNLINK=true
        echo -e "${CYAN}[UNLINK MODE — removing symlinks]${RESET}\n"
        ;;
    --help)
        echo "Usage: $0 [--dry-run | --unlink]"
        echo ""
        echo "  (no arguments)    Create symlinks using GNU Stow"
        echo "  --dry-run         Simulate the process"
        echo "  --unlink          Remove symlinks (unstow)"
        echo "  --help            Show this help"
        exit 0
        ;;
    *)
        log_error "Unknown argument: $arg"
        echo "Run '$0 --help' for options."
        exit 1
        ;;
    esac
done

# ── Dependency Check ──────────────────────────────────────────────────────────
if ! command -v stow &>/dev/null; then
    log_error "GNU Stow is not installed. Please install it using your package manager:"
    echo "  Arch Linux/CachyOS: sudo pacman -S stow"
    echo "  Debian/Ubuntu:      sudo apt install stow"
    echo "  Fedora:             sudo dnf install stow"
    exit 1
fi

# ── Stow Packages ─────────────────────────────────────────────────────────────
# Packages to exclude (not meant for stowing)
EXCLUDE=("scripts" "assets" "gemini" "combined_dots")

cd "$DOTFILES_DIR"

# Collect packages (directories that are not in EXCLUDE and don't start with .)
packages=()
for dir in */; do
    dir=${dir%/}
    [[ " ${EXCLUDE[@]} " =~ " ${dir} " ]] && continue
    [[ "$dir" == .* ]] && continue
    packages+=("$dir")
done

# Collect combined_dots packages if directory exists
combined_packages=()
if [ -d "$DOTFILES_DIR/combined_dots" ]; then
    for dir in combined_dots/*/; do
        [ -d "$dir" ] || continue
        dir=${dir#combined_dots/}
        dir=${dir%/}
        [[ " ${EXCLUDE[@]} " =~ " ${dir} " ]] && continue
        [[ "$dir" == .* ]] && continue
        combined_packages+=("$dir")
    done
fi

STOW_FLAGS="-v -t $HOME"
if [ "$DRY_RUN" = true ]; then
    STOW_FLAGS+=" -n"
fi

if [ "$UNLINK" = true ]; then
    STOW_FLAGS+=" -D"
    echo -e "${BLUE}Root packages to unstow:${RESET} ${packages[*]:-none}"
    if [ -d "$DOTFILES_DIR/combined_dots" ]; then
        if [ ${#combined_packages[@]} -gt 0 ]; then
            echo -e "${BLUE}Combined packages to unstow:${RESET} ${combined_packages[*]}"
        else
            log_info "No packages found in combined_dots/ (run 'git submodule update --init --recursive' if needed)"
        fi
    fi
    echo ""
else
    STOW_FLAGS+=" -S"
    echo -e "${BLUE}Root packages to stow:${RESET} ${packages[*]:-none}"
    if [ -d "$DOTFILES_DIR/combined_dots" ]; then
        if [ ${#combined_packages[@]} -gt 0 ]; then
            echo -e "${BLUE}Combined packages to stow:${RESET} ${combined_packages[*]}"
        else
            log_info "No packages found in combined_dots/ (run 'git submodule update --init --recursive' if needed)"
        fi
    fi
    echo ""
fi

# Stow root packages
for pkg in "${packages[@]}"; do
    if [ "$UNLINK" = true ]; then
        stow $STOW_FLAGS "$pkg" || log_error "Failed to unstow $pkg"
    else
        # Stow will fail if it encounters a real file instead of a symlink
        # We could add logic here to backup, but Stow's default behavior is safer
        stow $STOW_FLAGS "$pkg" || log_error "Failed to stow $pkg. Check for existing files."
    fi
done

# Stow combined_dots packages
if [ ${#combined_packages[@]} -gt 0 ]; then
    for pkg in "${combined_packages[@]}"; do
        if [ "$UNLINK" = true ]; then
            stow -d combined_dots $STOW_FLAGS "$pkg" || log_error "Failed to unstow combined_dots/$pkg"
        else
            stow -d combined_dots $STOW_FLAGS "$pkg" || log_error "Failed to stow combined_dots/$pkg. Check for existing files."
        fi
    done
fi

echo ""
if [ "$UNLINK" = true ]; then
    log_success "Unlink complete!"
else
    log_success "Stow complete!"
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YELLOW}(Dry-run mode — run without --dry-run to apply)${RESET}"
    fi
fi

exit 0
