#!/usr/bin/env bash
# OrchStep CLI installer — used by the setup-orchstep composite action.
# Defines pure functions plus a main dispatcher. No top-level `set -e` so it
# can be sourced by bats; main() enables strict mode itself.

cache_key() {
  echo "orchstep-$1-$2-$3"
}

detect_platform() {
  local os arch
  os="${1:-$(uname -s)}"
  arch="${2:-$(uname -m)}"
  case "$os" in
    Linux|linux)               os="linux" ;;
    Darwin|darwin|macOS)       os="darwin" ;;
    Windows*|windows|MINGW*|MSYS*|CYGWIN*) os="windows" ;;
    *) echo "ERROR: unsupported OS '$os'" >&2; return 1 ;;
  esac
  case "$arch" in
    x86_64|amd64|X64)          arch="amd64" ;;
    arm64|aarch64|ARM64)       arch="arm64" ;;
    *) echo "ERROR: unsupported architecture '$arch'" >&2; return 1 ;;
  esac
  echo "${os}/${arch}"
}

main() {
  set -euo pipefail
  echo "main not yet implemented" >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
