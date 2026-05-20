# Setup OrchStep

Install the [OrchStep](https://orchstep.dev) CLI on a GitHub Actions runner so
your jobs can run YAML-first workflow orchestration.

## Quick Start

```yaml
- uses: orchstep/setup-orchstep@v1
- run: orchstep run
```

This installs the latest OrchStep release, verifies it, puts it on `PATH`, and
runs your `orchstep.yml` workflow.

## Inputs

| Input         | Description                                              | Default               |
| ------------- | -------------------------------------------------------- | --------------------- |
| `version`     | Version to install: `latest` or a semver such as `1.2.3` | `latest`              |
| `token`       | GitHub token used for release API lookups                | `${{ github.token }}` |
| `cache`       | Cache the installed binary across runs                   | `true`                |
| `add-to-path` | Append the install directory to `PATH`                   | `true`                |
| `install-dir` | Install directory (default: the runner tool cache)       | `''`                  |

## Outputs

| Output        | Description                                |
| ------------- | ------------------------------------------ |
| `version`     | The resolved version that was installed    |
| `cache-hit`   | Whether a cached binary was reused         |
| `install-dir` | Absolute path to the install directory     |

## Examples

### Install latest and run a workflow

```yaml
jobs:
  orchestrate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: orchstep/setup-orchstep@v1
      - run: orchstep run
```

### Pin a specific version

```yaml
- uses: orchstep/setup-orchstep@v1
  with:
    version: '1.2.3'
```

### Lint workflows on a pull request

```yaml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: orchstep/setup-orchstep@v1
      - run: orchstep lint
```

### Build matrix across operating systems

```yaml
jobs:
  matrix:
    strategy:
      matrix:
        os: [ubuntu-latest, macos-latest, windows-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v4
      - uses: orchstep/setup-orchstep@v1
        with:
          version: '1.2.3'
      - run: orchstep run
```

## Security

Every downloaded release asset is verified against the SHA256 sums published in
the release's `checksums.txt` before it is extracted or placed on `PATH`. If a
checksum is missing or does not match, the action fails hard and nothing is
installed. Release lookups use the job's `github.token` by default; no secrets
are required.

## License

See [LICENSE](LICENSE).
