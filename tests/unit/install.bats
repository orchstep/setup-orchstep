#!/usr/bin/env bats

setup() {
  source "${BATS_TEST_DIRNAME}/../../install.sh"
}

@test "cache_key is deterministic and includes os, arch, version" {
  run cache_key linux amd64 1.2.3
  [ "$status" -eq 0 ]
  [ "$output" = "orchstep-linux-amd64-1.2.3" ]
}
