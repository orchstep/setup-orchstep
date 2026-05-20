#!/usr/bin/env bash
# Drives install.sh against the mock broken-release server and asserts
# that each tampered scenario causes a hard failure.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# install.sh is linted separately by the lint workflow.
# shellcheck disable=SC1091
source "${ROOT}/install.sh"

run_case() {
  local mode="$1" port="$2"
  python3 "${ROOT}/tests/negative/mock_server.py" "$mode" "$port" &
  local server_pid=$!
  # Poll for readiness instead of a fixed sleep — robust on a loaded runner.
  for _ in $(seq 1 50); do
    curl -fsS -o /dev/null "http://127.0.0.1:${port}/checksums.txt" && break
    sleep 0.1
  done
  local tmp; tmp="$(mktemp -d)"
  local rc=0
  # NOTE: `set -e` is intentionally not relied on here — when a subshell sits
  # on the left of `||`, bash disables errexit throughout it. Each step is
  # chained explicitly so any non-zero stops the pipeline.
  (
    download_asset "http://127.0.0.1:${port}/orchstep_9.9.9_linux_amd64.tar.gz" "${tmp}/asset.tar.gz" &&
    download_asset "http://127.0.0.1:${port}/checksums.txt" "${tmp}/checksums.txt" &&
    verify_checksum "${tmp}/asset.tar.gz" "${tmp}/checksums.txt" "orchstep_9.9.9_linux_amd64.tar.gz" &&
    # For wrong-checksum/missing-entry the line above already failed; for
    # truncated, verification passes and the corrupt archive fails here.
    mkdir -p "${tmp}/extracted" &&
    tar -xzf "${tmp}/asset.tar.gz" -C "${tmp}/extracted"
  ) || rc=$?
  kill "$server_pid" 2>/dev/null || true
  rm -rf "$tmp"
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL: mode '${mode}' should have caused a failure but did not" >&2
    return 1
  fi
  echo "PASS: mode '${mode}' failed as expected (rc=${rc})"
}

run_case wrong-checksum 8801
run_case missing-entry  8802
run_case truncated      8803
echo "all negative cases passed"
