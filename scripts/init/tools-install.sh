#!/usr/bin/env bash
# Copyright 2025 Kholis RA Gumelar or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: AGPL-3.0-only

set -e

# Function to check command existence
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "Error: $1 is not installed"
    return 1
  fi
  return 0
}

# Function to print installation instructions
print_install_instructions() {
  local tool="$1"
  case "$tool" in
    "homebrew")
      echo "Please install Homebrew first by visiting: https://brew.sh/"
      echo "Or run this command:"
      echo '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
      ;;
    "bun")
      echo "Please install Bun first by visiting: https://bun.sh/"
      echo "Or run one of these commands:"
      echo "curl -fsSL https://bun.sh/install | bash  # For macOS/Linux"
      echo "brew install bun                          # For macOS with Homebrew"
      ;;
    "go")
      echo "Please install Go first by visiting: https://go.dev/doc/install"
      echo "Or for macOS users:"
      echo "brew install go"
      ;;
  esac
}

# Function to print version
print_version() {
  local cmd="$1"
  local version_flag="${2:---version}"
  echo "$(${cmd} ${version_flag} 2>&1 || echo 'Error getting version')"
}

# Function to install on macOS
install_macos() {
  echo "Installing tools for macOS..."

  # Check if brew is installed
  if ! check_command "brew"; then
    echo "Error: Homebrew is not installed."
    print_install_instructions "homebrew"
    exit 1
  fi

  # Check if bun is installed
  if ! check_command "bun"; then
    echo "Bun is not installed. Installing via Homebrew..."
    brew install bun
  fi

  # Install packages using brew
  brew install go-task gitleaks goreleaser lefthook lima qemu lychee typos-cli

  # Install addlicense using go
  go install github.com/google/addlicense@latest
}

# Function to install on Linux
install_linux() {
  echo "Installing tools for Linux..."

  # Check if apt-get is available
  if ! check_command "apt-get"; then
    echo "Error: apt-get is not available. This script currently only supports Debian-based distributions."
    exit 1
  fi

  # Check if bun is installed
  if ! check_command "bun"; then
    echo "Bun is not installed."
    print_install_instructions "bun"
  fi

  # Install Go packages
  go install github.com/go-task/task/v3/cmd/task@latest
  go install github.com/goreleaser/goreleaser/v2@latest
  go install github.com/evilmartians/lefthook@latest
  go install github.com/google/addlicense@latest

  # Install Lima and other dependencies
  if ! check_command "curl" || ! check_command "jq"; then
    sudo apt-get update
    sudo apt-get install -y curl jq
  fi

  SYSTEM=$(uname -s)
  SYSTEM_LOWERCASE=$(uname -s | tr '[:upper:]' '[:lower:]')

  ARCH=$(uname -m)
  case "${ARCH}" in
    x86_64)
      MAPPING_ARCH_A="x86_64"
      MAPPING_ARCH_B="amd64"
      MAPPING_ARCH_C="x64"
      ;;
    aarch64)
      MAPPING_ARCH_A="aarch64"
      MAPPING_ARCH_B="arm64"
      MAPPING_ARCH_C="arm64"
      ;;
    *)
      echo "Unsupported architecture: ${ARCH}"
      exit 1
      ;;
  esac

  LIMAVM_VERSION=$(curl -fsSL https://api.github.com/repos/lima-vm/lima/releases/latest | jq -r .tag_name)
  curl -fsSL "https://github.com/lima-vm/lima/releases/download/${LIMAVM_VERSION}/lima-${LIMAVM_VERSION:1}-${SYSTEM}-${ARCH}.tar.gz" | sudo tar Cxzvm /usr/local

  LYCHEE_VERSION=$(curl -fsSL https://api.github.com/repos/lycheeverse/lychee/releases/latest | jq -r .tag_name)
  curl -fsSL "https://github.com/lycheeverse/lychee/releases/download/${LYCHEE_VERSION}/lychee-${MAPPING_ARCH_A}-unknown-${SYSTEM_LOWERCASE}-gnu.tar.gz" | sudo tar Cxzvm /usr/local

  GITLEAKS_VERSION=$(curl -fsSL https://api.github.com/repos/gitleaks/gitleaks/releases/latest | jq -r .tag_name)
  curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_${SYSTEM_LOWERCASE}_${MAPPING_ARCH_C}.tar.gz" | sudo tar Cxzvm /usr/local

  TYPOS_CLI_VERSION=$(curl -fsSL https://api.github.com/repos/crate-ci/typos/releases/latest | jq -r .tag_name)
  curl -fsSL "https://github.com/crate-ci/typos/releases/download/${TYPOS_CLI_VERSION}/typos-${TYPOS_CLI_VERSION}-${MAPPING_ARCH_A}-${SYSTEM_LOWERCASE}-gnu.tar.gz" | sudo tar Cxzvm /usr/local

  # Install QEMU
  sudo apt-get update
  sudo apt-get install -y qemu-system qemu-user-static
}

# Function to verify installations
verify_installations() {
  echo "Verifying installations..."

  # Check for required tools first
  for cmd in "go" "bun"; do
    if ! check_command "$cmd"; then
      echo "Error: $cmd is not installed."
      print_install_instructions "$cmd"
      exit 1
    fi
  done

  # Print versions of all tools
  echo -e "Go version:\n$(go version)"
  echo -e "Bun version:\n$(bun --version)"

  check_command "task" && echo -e "Task version:\n$(print_version "task")"
  check_command "gitleaks" && echo -e "Gitleaks version:\n$(print_version "gitleaks")"
  check_command "goreleaser" && echo -e "GoReleaser version:\n$(print_version "goreleaser")"
  check_command "lefthook" && echo -e "Lefthook version:\n$(lefthook version --full)"
  check_command "lima" && echo -e "Lima version:\n$(print_version "lima")"
  check_command "qemu-system-x86_64" && echo -e "QEMU version:\n$(print_version "qemu-system-x86_64")"

  # Verify addlicense is in PATH
  if ! check_command "addlicense"; then
    echo "Warning: addlicense not found in PATH. It might be installed in ~/go/bin/"
    if [ -f ~/go/bin/addlicense ]; then
      echo "Found addlicense in ~/go/bin/"
      echo "Consider adding ~/go/bin to your PATH"
    else
      echo "Error: addlicense not found"
      exit 1
    fi
  fi
}

# Main script
main() {
  echo "Tool Installation Script"
  echo "----------------------"

  # Check for Go and Bun
  if ! check_command "go"; then
    echo "Error: Go is not installed."
    print_install_instructions "go"
    exit 1
  fi
  echo "Using Go version: $(go version)"

  # Detect OS and run appropriate installation
  case "$(uname -s)" in
    Darwin)
      install_macos
      ;;
    Linux)
      install_linux
      ;;
    *)
      echo "Error: Unsupported operating system"
      exit 1
      ;;
  esac

  # Verify all installations
  verify_installations

  echo "All tools have been installed and verified successfully!"
  echo "Make sure to restart your terminal or source your shell configuration to use the newly installed tools."
}

main "$@"
