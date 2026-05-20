#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../../install.sh"
}

@test "cache_key is deterministic and includes os, arch, version" {
  run cache_key linux amd64 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "orchstep-linux-amd64-1.2.3" ]
}

@test "detect_platform normalizes linux x86_64" {
  run detect_platform Linux x86_64
  [ "$status" -eq 0 ]
  [ "$output" = "linux/amd64" ]
}

@test "detect_platform normalizes darwin arm64" {
  run detect_platform Darwin arm64
  [ "$status" -eq 0 ]
  [ "$output" = "darwin/arm64" ]
}

@test "detect_platform normalizes windows aarch64" {
  run detect_platform Windows_NT aarch64
  [ "$status" -eq 0 ]
  [ "$output" = "windows/arm64" ]
}

@test "detect_platform fails on unsupported arch" {
  run detect_platform Linux mips
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported architecture"* ]]
}

@test "detect_platform fails on unsupported os" {
  run detect_platform Plan9 x86_64
  [ "$status" -eq 1 ]
  [[ "$output" == *"unsupported OS"* ]]
}

@test "asset_url_for builds a tar.gz url for linux" {
  run asset_url_for 1.2.3 linux amd64
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/orchstep/orchstep/releases/download/v1.2.3/orchstep_1.2.3_linux_amd64.tar.gz" ]
}

@test "asset_url_for builds a zip url for windows" {
  run asset_url_for 1.2.3 windows amd64
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/orchstep/orchstep/releases/download/v1.2.3/orchstep_1.2.3_windows_amd64.zip" ]
}

@test "checksums_url_for builds the checksums url" {
  run checksums_url_for 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "https://github.com/orchstep/orchstep/releases/download/v1.2.3/checksums.txt" ]
}

@test "resolve_version strips v prefix from semver" {
  run resolve_version v1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "resolve_version accepts bare semver" {
  run resolve_version 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "resolve_version resolves latest via _fetch_latest_tag" {
  _fetch_latest_tag() { echo "v1.4.2"; }
  run resolve_version latest
  [ "$status" -eq 0 ]
  [ "$output" = "1.4.2" ]
}

@test "resolve_version fails on garbage input" {
  run resolve_version "not-a-version"
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid version"* ]]
}

@test "resolve_version fails when latest cannot be resolved" {
  _fetch_latest_tag() { echo ""; }
  run resolve_version latest
  [ "$status" -eq 1 ]
  [[ "$output" == *"could not resolve"* ]]
}

@test "verify_checksum passes for a matching file" {
  local tmp; tmp="$(mktemp -d)"
  echo "hello orchstep" > "${tmp}/asset.tar.gz"
  local hash
  if command -v sha256sum >/dev/null 2>&1; then
    hash="$(sha256sum "${tmp}/asset.tar.gz" | awk '{print $1}')"
  else
    hash="$(shasum -a 256 "${tmp}/asset.tar.gz" | awk '{print $1}')"
  fi
  printf '%s  asset.tar.gz\n' "$hash" > "${tmp}/checksums.txt"
  run verify_checksum "${tmp}/asset.tar.gz" "${tmp}/checksums.txt" "asset.tar.gz"
  [ "$status" -eq 0 ]
  rm -rf "$tmp"
}

@test "verify_checksum fails on a mismatch" {
  local tmp; tmp="$(mktemp -d)"
  echo "tampered" > "${tmp}/asset.tar.gz"
  printf '%s  asset.tar.gz\n' "0000000000000000000000000000000000000000000000000000000000000000" > "${tmp}/checksums.txt"
  run verify_checksum "${tmp}/asset.tar.gz" "${tmp}/checksums.txt" "asset.tar.gz"
  [ "$status" -eq 1 ]
  [[ "$output" == *"checksum mismatch"* ]]
  rm -rf "$tmp"
}

@test "verify_checksum fails when the asset has no checksum entry" {
  local tmp; tmp="$(mktemp -d)"
  echo "data" > "${tmp}/asset.tar.gz"
  printf '%s  other-file.tar.gz\n' "abc123" > "${tmp}/checksums.txt"
  run verify_checksum "${tmp}/asset.tar.gz" "${tmp}/checksums.txt" "asset.tar.gz"
  [ "$status" -eq 1 ]
  [[ "$output" == *"no checksum entry"* ]]
  rm -rf "$tmp"
}

@test "download_asset succeeds on the first try" {
  local tmp; tmp="$(mktemp -d)"
  curl() { echo "payload" > "${tmp}/out"; return 0; }
  export -f curl
  run download_asset "http://example/x" "${tmp}/out"
  [ "$status" -eq 0 ]
  [ -s "${tmp}/out" ]
  rm -rf "$tmp"
}

@test "download_asset retries then fails after 3 attempts" {
  local tmp; tmp="$(mktemp -d)"
  curl() { return 22; }
  export -f curl
  ORCHSTEP_RETRY_SLEEP=0 run download_asset "http://example/x" "${tmp}/out"
  [ "$status" -eq 1 ]
  [[ "$output" == *"failed to download"* ]]
  rm -rf "$tmp"
}

@test "do_plan writes resolved fields to GITHUB_OUTPUT" {
  local tmp; tmp="$(mktemp -d)"
  _fetch_latest_tag() { echo "v2.0.1"; }
  INPUT_VERSION="latest" \
  INPUT_INSTALL_DIR="${tmp}/install" \
  RUNNER_TOOL_CACHE="${tmp}/toolcache" \
  GITHUB_OUTPUT="${tmp}/out" \
    run bash -c 'source '"${BATS_TEST_DIRNAME}"'/../../install.sh; _fetch_latest_tag() { echo v2.0.1; }; do_plan'
  [ "$status" -eq 0 ]
  grep -q "version=2.0.1" "${tmp}/out"
  grep -q "cache-key=orchstep-" "${tmp}/out"
  grep -q "install-dir=${tmp}/install" "${tmp}/out"
  rm -rf "$tmp"
}

@test "main rejects an unknown mode" {
  run bash "${BATS_TEST_DIRNAME}/../../install.sh" bogus-mode
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown mode"* ]]
}
