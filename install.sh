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

asset_url_for() {
  local version="$1" os="$2" arch="$3" ext="tar.gz"
  [[ "$os" == "windows" ]] && ext="zip"
  echo "https://github.com/orchstep/orchstep/releases/download/v${version}/orchstep_${version}_${os}_${arch}.${ext}"
}

checksums_url_for() {
  echo "https://github.com/orchstep/orchstep/releases/download/v${1}/checksums.txt"
}

_fetch_latest_tag() {
  local api="${GITHUB_API_URL:-https://api.github.com}"
  local auth=()
  [[ -n "${GITHUB_TOKEN:-}" ]] && auth=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  curl -fsSL "${auth[@]}" "${api}/repos/orchstep/orchstep/releases/latest" \
    | grep '"tag_name"' | head -1 \
    | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/'
}

resolve_version() {
  local input="$1"
  case "$input" in
    latest)
      local tag
      tag="$(_fetch_latest_tag)"
      if [[ -z "$tag" ]]; then
        echo "ERROR: could not resolve latest version from GitHub API" >&2
        return 1
      fi
      echo "${tag#v}"
      ;;
    v[0-9]*|[0-9]*)
      local stripped="${input#v}"
      if [[ ! "$stripped" =~ ^[0-9]+\.[0-9]+\.[0-9]+([.-].*)?$ ]]; then
        echo "ERROR: invalid version '$input' (expected semver like 1.2.3)" >&2
        return 1
      fi
      echo "$stripped"
      ;;
    *)
      echo "ERROR: invalid version '$input' (expected 'latest' or a semver)" >&2
      return 1
      ;;
  esac
}

verify_checksum() {
  local file="$1" checksums="$2" name="$3"
  local expected actual
  # GoReleaser checksums.txt format: "<sha256>  <filename>"
  expected="$(grep -E "  ${name}\$" "$checksums" | awk '{print $1}' | head -1)"
  if [[ -z "$expected" ]]; then
    echo "ERROR: no checksum entry for '${name}' in checksums.txt" >&2
    return 1
  fi
  if command -v sha256sum >/dev/null 2>&1; then
    actual="$(sha256sum "$file" | awk '{print $1}')"
  else
    actual="$(shasum -a 256 "$file" | awk '{print $1}')"
  fi
  if [[ "$expected" != "$actual" ]]; then
    echo "ERROR: checksum mismatch for '${name}': expected ${expected}, got ${actual}" >&2
    return 1
  fi
  echo "checksum verified for ${name}"
}

main() {
  set -euo pipefail
  echo "main not yet implemented" >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
