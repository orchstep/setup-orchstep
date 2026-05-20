#!/usr/bin/env bash
# OrchStep CLI installer — used by the setup-orchstep composite action.
# Defines pure functions plus a main dispatcher. No top-level `set -e` so it
# can be sourced by bats; main() enables strict mode itself.

cache_key() {
  echo "orchstep-$1-$2-$3"
}

main() {
  set -euo pipefail
  echo "main not yet implemented" >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
