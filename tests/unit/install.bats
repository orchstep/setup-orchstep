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
