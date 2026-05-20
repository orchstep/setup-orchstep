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
  expected="$(awk -v n="$name" '$2 == n {print $1}' "$checksums" | head -1)"
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

download_asset() {
  local url="$1" dest="$2" attempt=1 max=3
  local sleep_base="${ORCHSTEP_RETRY_SLEEP:-2}"
  while (( attempt <= max )); do
    if curl -fsSL -o "$dest" "$url" && [[ -s "$dest" ]]; then
      return 0
    fi
    echo "WARN: download failed (attempt ${attempt}/${max}): ${url}" >&2
    if (( attempt < max )); then
      sleep $(( attempt * sleep_base ))
    fi
    (( attempt++ ))
  done
  echo "ERROR: failed to download ${url} after ${max} attempts" >&2
  return 1
}

do_plan() {
  local version platform os arch install_dir
  version="$(resolve_version "${INPUT_VERSION:-latest}")"
  platform="$(detect_platform)"
  os="${platform%/*}"
  arch="${platform#*/}"
  if [[ -n "${INPUT_INSTALL_DIR:-}" ]]; then
    install_dir="${INPUT_INSTALL_DIR}"
  else
    install_dir="${RUNNER_TOOL_CACHE:-/tmp/orchstep-toolcache}/orchstep/${version}/${arch}"
  fi
  {
    echo "version=${version}"
    echo "os=${os}"
    echo "arch=${arch}"
    echo "cache-key=$(cache_key "$os" "$arch" "$version")"
    echo "install-dir=${install_dir}"
  } >> "${GITHUB_OUTPUT:-/dev/stdout}"
}

do_install() {
  local version="${PLAN_VERSION:?PLAN_VERSION is required}"
  local os="${PLAN_OS:?PLAN_OS is required}"
  local arch="${PLAN_ARCH:?PLAN_ARCH is required}"
  local install_dir="${PLAN_INSTALL_DIR:?PLAN_INSTALL_DIR is required}"
  local bin_name="orchstep"
  [[ "$os" == "windows" ]] && bin_name="orchstep.exe"
  local bin_path="${install_dir}/${bin_name}"
  local cache_hit="false"

  if [[ -x "$bin_path" ]]; then
    cache_hit="true"
    echo "::notice::OrchStep ${version} restored from cache"
  else
    mkdir -p "$install_dir"
    local ext="tar.gz"
    [[ "$os" == "windows" ]] && ext="zip"
    local asset="orchstep_${version}_${os}_${arch}.${ext}"
    local tmp
    tmp="$(mktemp -d)"
    # Fires once on do_install's return to clean up the temp dir on any path;
    # `trap - RETURN` disarms it so it cannot fire again (defensive — also
    # correct should `set -o functrace` ever be enabled).
    trap 'rm -rf "$tmp"; trap - RETURN' RETURN
    download_asset "$(asset_url_for "$version" "$os" "$arch")" "${tmp}/${asset}" || return 1
    download_asset "$(checksums_url_for "$version")" "${tmp}/checksums.txt" || return 1
    # Gate: extraction must not proceed unless the checksum verifies. Checked
    # explicitly so this holds even when do_install runs without `set -e`.
    verify_checksum "${tmp}/${asset}" "${tmp}/checksums.txt" "$asset" || return 1
    if [[ "$ext" == "zip" ]]; then
      unzip -o -j "${tmp}/${asset}" "$bin_name" -d "$tmp" >/dev/null
    else
      tar -xzf "${tmp}/${asset}" -C "$tmp" "$bin_name"
    fi
    if [[ ! -f "${tmp}/${bin_name}" ]]; then
      echo "ERROR: '${bin_name}' not found in ${asset}" >&2
      return 1
    fi
    mv "${tmp}/${bin_name}" "$bin_path"
    chmod +x "$bin_path"
    echo "::notice::OrchStep ${version} installed to ${install_dir}"
  fi

  local reported
  reported="$("$bin_path" version 2>&1 | head -1 || true)"
  if [[ "$reported" != *"$version"* ]]; then
    echo "ERROR: smoke test failed — '${bin_path} version' reported '${reported}', expected to contain '${version}'" >&2
    return 1
  fi

  if [[ "${INPUT_ADD_TO_PATH:-true}" == "true" ]]; then
    echo "$install_dir" >> "${GITHUB_PATH:-/dev/stdout}"
  fi

  {
    echo "version=${version}"
    echo "cache-hit=${cache_hit}"
    echo "install-dir=${install_dir}"
  } >> "${GITHUB_OUTPUT:-/dev/stdout}"
}

main() {
  set -euo pipefail
  local mode="${1:-install}"
  case "$mode" in
    plan)    do_plan ;;
    install) do_install ;;
    *)
      echo "ERROR: unknown mode '${mode}' (expected 'plan' or 'install')" >&2
      exit 1
      ;;
  esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
