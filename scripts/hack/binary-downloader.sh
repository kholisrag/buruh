#!/usr/bin/env bash
# Copyright 2025 Kholis RA Gumelar or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: AGPL-3.0-only


set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_NAME="$(basename "$0")"
readonly REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo "${SCRIPT_DIR}")"

# Debug mode flag
DEBUG=false

# Default versions
FLINTLOCK_VERSION="v0.7.0"
FIRECRACKER_VERSION="v1.10.1"
CONTAINERD_VERSION="v2.0.2"
CLOUD_HYPERVISOR_VERSION="v43.0"
FL_VERSION="v0.2.1"
HAMMERTIME_VERSION="v0.0.11"
TTYD_VERSION="1.7.7"

# Default installation directory
INSTALL_DIR="${REPO_ROOT}/pkg/utils/.bin"
TEMP_DIR="${REPO_ROOT}/temp/download"
ARCH=$(uname -m)

# Architecture mappings
function get_normalized_arch() {
  local arch="$1"
  case "$arch" in
    "x86_64"|"amd64")
      case "$2" in
        "flintlock"|"containerd"|"hammertime") echo "amd64" ;;
        "firecracker"|"ttyd") echo "x86_64" ;;
        "fl") echo "x86_64" ;;
        "cloud-hypervisor") echo "x86_64" ;;
      esac
      ;;
    "aarch64"|"arm64")
      case "$2" in
        "flintlock"|"containerd"|"hammertime") echo "arm64" ;;
        "firecracker"|"ttyd"|"cloud-hypervisor") echo "aarch64" ;;
        "fl") echo "arm64" ;;
      esac
      ;;
    *)
      echo ""
      ;;
  esac
}

function log() {
  local readonly level="$1"
  local readonly message="$2"
  local readonly timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  >&2 echo -e "${timestamp} [${level}] [$SCRIPT_NAME] ${message}"
}

function log_info() {
  local readonly message="$1"
  log "INFO" "$message"
}

function log_warn() {
  local readonly message="$1"
  log "WARN" "$message"
}

function log_error() {
  local readonly message="$1"
  log "ERROR" "$message"
}

# Check if running on Linux
if [[ "$(uname -s)" != "Linux" ]]; then
  log_warn "Warning: This script is designed for Linux systems and downloads Linux binaries."
fi

function check_dependencies() {
  local deps=(curl jq tar)
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" >/dev/null 2>&1; then
      log_error "Missing dependency: $dep"
      exit 1
    fi
  done
}

function download_with_checksum() {
  local url="$1"
  local output="$2"
  local checksum_url="${3:-}"
  local checksum_type="${4:-sha256}"

  log_info "Downloading from ${url}"
  if ! curl -fsSL "$url" -o "$output"; then
    log_error "Failed to download from $url"
    return 1
  fi

  if [ -n "$checksum_url" ]; then
    log_info "Verifying checksum from ${checksum_url}"
    # Download checksum file
    local checksum_file="${TEMP_DIR}/$(basename "$url").sha256"
    if ! curl -fsSL "$checksum_url" -o "$checksum_file"; then
      log_error "Failed to download checksum from $checksum_url"
      rm -f "$output"
      return 1
    fi

    # Calculate actual checksum
    local actual_sum=$(sha256sum "$output" | awk '{print $1}')

    # Look for matching checksum in the file
    if ! grep -q "$actual_sum" "$checksum_file"; then
      log_error "No matching checksum found in ${checksum_file}"
      cat "$checksum_file" | while read -r line; do
        log_info "Available checksum: $line"
      done
      log_info "Actual checksum:   ${actual_sum}"
      rm -f "$output" "$checksum_file"
      return 1
    fi

    rm -f "$checksum_file"
    log_info "Checksum verified successfully"
  fi
}

function install_flintlock() {
  log_info "Installing Flintlock ${FLINTLOCK_VERSION}..."
  local target_arch=$(get_normalized_arch "$ARCH" "flintlock")
  if [ -z "$target_arch" ]; then
    log_error "Unsupported architecture for Flintlock: $ARCH"
    return 1
  fi

  local base_url="https://github.com/liquidmetal-dev/flintlock/releases/download/${FLINTLOCK_VERSION}"

  # Download flintlockd
  download_with_checksum \
    "${base_url}/flintlockd_${target_arch}" \
    "${INSTALL_DIR}/flintlockd"
  chmod +x "${INSTALL_DIR}/flintlockd"

  # Download flintlock-metrics
  download_with_checksum \
    "${base_url}/flintlock-metrics_${target_arch}" \
    "${INSTALL_DIR}/flintlock-metrics"
  chmod +x "${INSTALL_DIR}/flintlock-metrics"
}

function install_firecracker() {
  log_info "Installing Firecracker ${FIRECRACKER_VERSION}..."
  local target_arch=$(get_normalized_arch "$ARCH" "firecracker")
  if [ -z "$target_arch" ]; then
    log_error "Unsupported architecture for Firecracker: $ARCH"
    return 1
  fi

  local base_url="https://github.com/firecracker-microvm/firecracker/releases/download/${FIRECRACKER_VERSION}"
  local tarball="${TEMP_DIR}/firecracker.tgz"
  local release_dir="${TEMP_DIR}/firecracker/release-${FIRECRACKER_VERSION}-${target_arch}"

  download_with_checksum \
    "${base_url}/firecracker-${FIRECRACKER_VERSION}-${target_arch}.tgz" \
    "$tarball" \
    "${base_url}/firecracker-${FIRECRACKER_VERSION}-${target_arch}.tgz.sha256.txt"

  mkdir -p "${TEMP_DIR}/firecracker"
  tar xzf "$tarball" -C "${TEMP_DIR}/firecracker"

  # Install all the binaries without version suffix
  local binaries=(
    "cpu-template-helper"
    "firecracker"
    "jailer"
    "rebase-snap"
    "seccompiler-bin"
    "snapshot-editor"
  )

  for binary in "${binaries[@]}"; do
    local src="${release_dir}/${binary}-${FIRECRACKER_VERSION}-${target_arch}"
    local dst="${INSTALL_DIR}/${binary}"
    log_info "Installing ${binary}..."
    install "$src" "$dst"
    chmod +x "$dst"
  done
}

function install_containerd() {
  log_info "Installing containerd ${CONTAINERD_VERSION}..."
  local target_arch=$(get_normalized_arch "$ARCH" "containerd")
  if [ -z "$target_arch" ]; then
    log_error "Unsupported architecture for containerd: $ARCH"
    return 1
  fi

  local base_url="https://github.com/containerd/containerd/releases/download/${CONTAINERD_VERSION}"
  local version_no_v="${CONTAINERD_VERSION#v}"
  local tarball="${TEMP_DIR}/containerd.tar.gz"

  download_with_checksum \
    "${base_url}/containerd-${version_no_v}-linux-${target_arch}.tar.gz" \
    "$tarball" \
    "${base_url}/containerd-${version_no_v}-linux-${target_arch}.tar.gz.sha256sum"

  mkdir -p "${TEMP_DIR}/containerd"
  tar xzf "$tarball" -C "${TEMP_DIR}/containerd"

  # Install all containerd binaries
  local binaries=(
    "containerd"
    "containerd-shim-runc-v2"
    "containerd-stress"
    "ctr"
  )

  for binary in "${binaries[@]}"; do
    log_info "Installing ${binary}..."
    install "${TEMP_DIR}/containerd/bin/${binary}" "${INSTALL_DIR}/${binary}"
    chmod +x "${INSTALL_DIR}/${binary}"
  done
}

function install_cloud_hypervisor() {
  log_info "Installing Cloud Hypervisor ${CLOUD_HYPERVISOR_VERSION}..."
  local target_arch=$(get_normalized_arch "$ARCH" "cloud-hypervisor")
  if [ -z "$target_arch" ]; then
    log_error "Unsupported architecture for Cloud Hypervisor: $ARCH"
    return 1
  fi

  local arch_suffix=""
  [[ "$target_arch" == "aarch64" ]] && arch_suffix="-aarch64"

  local download_url="https://github.com/cloud-hypervisor/cloud-hypervisor/releases/download/${CLOUD_HYPERVISOR_VERSION}/cloud-hypervisor-static${arch_suffix}"

  download_with_checksum "$download_url" "${INSTALL_DIR}/cloud-hypervisor"
  chmod +x "${INSTALL_DIR}/cloud-hypervisor"
}

function install_fl() {
  log_info "Installing fl ${FL_VERSION}..."
  local target_arch=$(get_normalized_arch "$ARCH" "fl")
  if [ -z "$target_arch" ]; then
    log_error "Unsupported architecture for fl: $ARCH"
    return 1
  fi

  local tarball="${TEMP_DIR}/fl.tar.gz"
  local download_url="https://github.com/liquidmetal-dev/fl/releases/download/${FL_VERSION}/fl_Linux_${target_arch}.tar.gz"

  download_with_checksum "$download_url" "$tarball" \
    "https://github.com/liquidmetal-dev/fl/releases/download/${FL_VERSION}/checksums.txt"

  mkdir -p "${TEMP_DIR}/fl"
  tar xzf "$tarball" -C "${TEMP_DIR}/fl"
  install "${TEMP_DIR}/fl/fl" "${INSTALL_DIR}/fl"
}

function install_hammertime() {
  log_info "Installing hammertime ${HAMMERTIME_VERSION}..."
  local target_arch=$(get_normalized_arch "$ARCH" "hammertime")
  if [ -z "$target_arch" ]; then
    log_error "Unsupported architecture for hammertime: $ARCH"
    return 1
  fi

  local download_url="https://github.com/warehouse-13/hammertime/releases/download/${HAMMERTIME_VERSION}/hammertime-linux-${target_arch}"

  download_with_checksum "$download_url" "${INSTALL_DIR}/hammertime"
  chmod +x "${INSTALL_DIR}/hammertime"
}

function install_ttyd() {
  log_info "Installing ttyd ${TTYD_VERSION}..."
  local target_arch=$(get_normalized_arch "$ARCH" "ttyd")
  if [ -z "$target_arch" ]; then
    log_error "Unsupported architecture for ttyd: $ARCH"
    return 1
  fi

  local download_url="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.${target_arch}"

  download_with_checksum "$download_url" "${INSTALL_DIR}/ttyd" \
    "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/SHA256SUMS"

  chmod +x "${INSTALL_DIR}/ttyd"
}

function setup_directories() {
  mkdir -p "${INSTALL_DIR}"
  mkdir -p "${TEMP_DIR}"
}

function cleanup() {
  if [ "$DEBUG" = false ]; then
    rm -rf "${TEMP_DIR}"
  else
    log_info "Debug mode: Keeping temporary directory at ${TEMP_DIR}"
  fi
}

function print_usage() {
  cat << EOF
Usage: $0 [OPTIONS]

Options:
  --flintlock-version VERSION    Specify Flintlock version (default: ${FLINTLOCK_VERSION})
  --firecracker-version VERSION  Specify Firecracker version (default: ${FIRECRACKER_VERSION})
  --containerd-version VERSION   Specify containerd version (default: ${CONTAINERD_VERSION})
  --cloud-hypervisor-version VERSION Specify Cloud Hypervisor version (default: ${CLOUD_HYPERVISOR_VERSION})
  --fl-version VERSION          Specify fl version (default: ${FL_VERSION})
  --hammertime-version VERSION  Specify hammertime version (default: ${HAMMERTIME_VERSION})
  --ttyd-version VERSION        Specify ttyd version (default: ${TTYD_VERSION})
  --install-dir DIR             Specify installation directory (default: ${INSTALL_DIR})
  --debug                       Enable debug mode (keeps temporary files)
  -h, --help                    Show this help message

Example:
  $0 --flintlock-version v0.7.0 --install-dir /usr/local/bin
EOF
}

function parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --flintlock-version)
        FLINTLOCK_VERSION="$2"
        shift 2
        ;;
      --firecracker-version)
        FIRECRACKER_VERSION="$2"
        shift 2
        ;;
      --containerd-version)
        CONTAINERD_VERSION="$2"
        shift 2
        ;;
      --cloud-hypervisor-version)
        CLOUD_HYPERVISOR_VERSION="$2"
        shift 2
        ;;
      --fl-version)
        FL_VERSION="$2"
        shift 2
        ;;
      --hammertime-version)
        HAMMERTIME_VERSION="$2"
        shift 2
        ;;
      --ttyd-version)
        TTYD_VERSION="$2"
        shift 2
        ;;
      --install-dir)
        INSTALL_DIR="$2"
        shift 2
        ;;
      --debug)
        DEBUG=true
        shift 1
        ;;
      -h|--help)
        print_usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        print_usage
        exit 1
        ;;
    esac
  done
}

function main() {
  parse_args "$@"
  check_dependencies
  setup_directories

  trap cleanup EXIT

  # Install components
  install_flintlock
  install_firecracker
  install_containerd
  install_cloud_hypervisor
  install_fl
  install_hammertime
  install_ttyd

  log_info "Installation completed successfully!"
  log_info "Binaries installed in: ${INSTALL_DIR}"
  log_info "Make sure ${INSTALL_DIR} is in your PATH"
}

main "$@"
