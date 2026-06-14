# Changelog

## [1.0.0] - 2026-05-20

### Added

- Initial release: composite action that installs the OrchStep CLI.
- Inputs: `version`, `token`, `cache`, `add-to-path`, `install-dir`.
- Outputs: `version`, `cache-hit`, `install-dir`.
- SHA256 checksum verification of every downloaded release asset.
- Binary caching across runs via `actions/cache`.
- Support for Linux, macOS, and Windows runners on amd64 and arm64.
