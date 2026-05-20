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
