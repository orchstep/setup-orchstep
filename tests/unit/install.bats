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

@test "do_install uses the cached binary when present" {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "${tmp}/install"
  cat > "${tmp}/install/orchstep" <<'EOF'
#!/usr/bin/env bash
echo "orchstep version 1.2.3"
EOF
  chmod +x "${tmp}/install/orchstep"
  PLAN_VERSION=1.2.3 PLAN_OS=linux PLAN_ARCH=amd64 \
  PLAN_INSTALL_DIR="${tmp}/install" \
  GITHUB_OUTPUT="${tmp}/out" GITHUB_PATH="${tmp}/path" \
    run do_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"restored from cache"* ]]
  grep -q "cache-hit=true" "${tmp}/out"
  grep -q "version=1.2.3" "${tmp}/out"
  grep -qx "${tmp}/install" "${tmp}/path"
  rm -rf "$tmp"
}

@test "do_install downloads, extracts, and installs a fresh binary" {
  local tmp; tmp="$(mktemp -d)"

  # Stub download_asset: drop a real tar.gz containing a fake orchstep binary,
  # and a valid checksums.txt for that archive.
  download_asset() {
    local url="$1" dest="$2"
    case "$dest" in
      *checksums.txt)
        local asset_dir asset_name
        asset_dir="$(dirname "$dest")"
        asset_name="orchstep_1.2.3_linux_amd64.tar.gz"
        local hash
        if command -v sha256sum >/dev/null 2>&1; then
          hash="$(sha256sum "${asset_dir}/${asset_name}" | awk '{print $1}')"
        else
          hash="$(shasum -a 256 "${asset_dir}/${asset_name}" | awk '{print $1}')"
        fi
        printf '%s  %s\n' "$hash" "$asset_name" > "$dest"
        ;;
      *.tar.gz)
        local build; build="$(mktemp -d)"
        cat > "${build}/orchstep" <<'EOF'
#!/usr/bin/env bash
echo "orchstep version 1.2.3"
EOF
        chmod +x "${build}/orchstep"
        tar -czf "$dest" -C "$build" orchstep
        rm -rf "$build"
        ;;
    esac
    return 0
  }

  PLAN_VERSION=1.2.3 PLAN_OS=linux PLAN_ARCH=amd64 \
  PLAN_INSTALL_DIR="${tmp}/install" \
  GITHUB_OUTPUT="${tmp}/out" GITHUB_PATH="${tmp}/path" \
    run do_install
  [ "$status" -eq 0 ]
  [[ "$output" == *"installed to"* ]]
  [ -x "${tmp}/install/orchstep" ]
  grep -q "cache-hit=false" "${tmp}/out"
  grep -q "version=1.2.3" "${tmp}/out"
  rm -rf "$tmp"
}

@test "do_install fails when the smoke test reports the wrong version" {
  local tmp; tmp="$(mktemp -d)"
  mkdir -p "${tmp}/install"
  cat > "${tmp}/install/orchstep" <<'EOF'
#!/usr/bin/env bash
echo "orchstep version 9.9.9"
EOF
  chmod +x "${tmp}/install/orchstep"
  PLAN_VERSION=1.2.3 PLAN_OS=linux PLAN_ARCH=amd64 \
  PLAN_INSTALL_DIR="${tmp}/install" \
  GITHUB_OUTPUT="${tmp}/out" GITHUB_PATH="${tmp}/path" \
    run do_install
  [ "$status" -ne 0 ]
  [[ "$output" == *"smoke test failed"* ]]
  rm -rf "$tmp"
}
