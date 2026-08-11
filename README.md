# GemGuard

[![Gem Version](https://badge.fury.io/rb/gem_guard.svg)](https://badge.fury.io/rb/gem_guard)
[![CI](https://github.com/wilburhimself/gem_guard/workflows/CI/badge.svg)](https://github.com/wilburhimself/gem_guard/actions/workflows/ci.yml)
[![Release](https://github.com/wilburhimself/gem_guard/workflows/Release/badge.svg)](https://github.com/wilburhimself/gem_guard/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Security Policy](https://img.shields.io/badge/Security-Policy-blue.svg)](https://github.com/wilburhimself/gem_guard/blob/main/SECURITY.md)

A Ruby dependency security scanner and SBOM generator. GemGuard checks your `Gemfile.lock` against five vulnerability sources, flags gems whose names look like typosquats of popular ones, and generates SPDX or CycloneDX SBOMs — all from one CLI, with CI-friendly exit codes.

`bundler-audit` checks one source and stops there. GemGuard exists because that's not enough coverage for anything running in production, and because vulnerability scanning, typosquat detection, and SBOM generation are three tasks most teams end up bolting together from separate tools when they could be one.

**Status:** actively maintained, single-maintainer project. Solid test coverage and a real release pipeline (see below), still early in adoption. If you're evaluating it for a team, read the source — it's small enough to actually do that before you depend on it.

## What it does

- **Vulnerability scanning** — cross-references OSV.dev, the Ruby Advisory Database, GitHub Security Advisories, NVD, and the Curesec Advisory Database, deduplicated across platform-specific gem variants. Output includes exact fix commands, not just CVE IDs.
- **Typosquat detection** — fuzzy-matches your dependency names against known popular gems, with a configurable similarity threshold and risk classification.
- **SBOM generation** — SPDX 2.3 or CycloneDX 1.5, with full dependency metadata, licenses, and checksums.
- **CI/CD integration** — configurable exit codes, JSON output, and a `.gemguard.yml` for pipeline control.

## Installation

```bash
gem install gem_guard
```

Or add it to your Gemfile:

```ruby
gem 'gem_guard'
```

## Quick start

```bash
gem_guard scan        # vulnerability scan
gem_guard typosquat    # typosquat check
gem_guard sbom         # generate an SBOM
```

## Usage

### Vulnerability scanning

```bash
gem_guard scan
gem_guard scan --lockfile path/to/Gemfile.lock
gem_guard scan --format json --output vulnerabilities.json
gem_guard scan --fail-on-vulnerabilities --severity-threshold high
```

Exit codes: `0` success, `1` vulnerabilities found (only with `--fail-on-vulnerabilities`), `2` error.

Example output:

```
🚨 Security Vulnerabilities Found
==================================================
Summary:
  Total vulnerabilities: 2
  High/Critical severity: 1

📦 nokogiri (1.18.8)
   Vulnerability: GHSA-353f-x4gh-cqq8
   Severity: UNKNOWN
   Fix: bundle update nokogiri --to 1.18.9

📦 thor (1.3.2)
   Vulnerability: GHSA-mqcp-p2hv-vw6x
   Severity: CVSS:3.1/AV:L/AC:H/PR:L/UI:N/S:C/C:H/I:H/A:H
   Fix: bundle update thor --to 1.4.0
```

### Auto-fixing vulnerable dependencies

```bash
gem_guard fix --dry-run       # preview only, no files modified
gem_guard fix --interactive   # choose which upgrades to apply
gem_guard fix                 # apply all recommended fixes
```

A backup (`Gemfile.lock.backup.YYYYMMDD_HHMMSS`) is created only when at least one fix is applied. `fix` requires both `Gemfile` and `Gemfile.lock` to exist; interactive mode requires a TTY.

Exit codes: `0` success, `2` error.

### Interactive mode

```bash
gem_guard interactive
```

Scans, shows results, then offers to drop into interactive fixing.

### Typosquat detection

```bash
gem_guard typosquat
gem_guard typosquat --threshold 0.9
gem_guard typosquat --format json --output typosquats.json
```

```
🎯 Potential Typosquat Dependencies Found
==========================================
📦 railz (7.0.0)
   Risk Level: CRITICAL
   Similarity: 80.0% to 'rails'
   Consider: Did you mean 'rails'? Review this dependency carefully.
```

Exit codes: `0` no high/critical risk, `1` high/critical risk found, `2` error.

### SBOM generation

```bash
gem_guard sbom                                   # SPDX (default)
gem_guard sbom --format cyclone-dx
gem_guard sbom --project my-app --output sbom.json
```

## Configuration

Project-level config via `.gemguard.yml`:

```yaml
lockfile_path: "Gemfile.lock"
output_format: "table"          # table, json
fail_on_vulnerabilities: true
severity_threshold: "medium"    # low, medium, high, critical
output_file: null
ignore_vulnerabilities:
  - "CVE-2021-12345"
  - "GHSA-xxxx-xxxx-xxxx"
typosquat:
  similarity_threshold: 0.8
  enabled: true
sbom:
  format: "spdx"                # spdx, cyclone-dx
  project_name: "my-project"
scan:
  sources:
    - "osv"
    - "ruby_advisory_db"
    - "ghsa"
    - "nvd"
    - "cu_advisory_db"
```

| Option | Description | Default |
|---|---|---|
| `lockfile_path` | Path to Gemfile.lock | `"Gemfile.lock"` |
| `output_format` | table or json | `"table"` |
| `fail_on_vulnerabilities` | Exit 1 if vulnerabilities found | `true` |
| `severity_threshold` | Minimum severity to report | `"low"` |
| `output_file` | Write output to file | `null` |
| `ignore_vulnerabilities` | CVE/GHSA IDs to ignore | `[]` |
| `typosquat.similarity_threshold` | Detection sensitivity | `0.8` |
| `typosquat.enabled` | Enable typosquat detection | `true` |
| `sbom.format` | spdx or cyclone-dx | `"spdx"` |
| `sbom.project_name` | Project name in SBOM | `"ruby-project"` |
| `scan.sources` | Vulnerability sources checked | all five |

## CI/CD

**GitHub Actions**

```yaml
name: Security Scan
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.2'
          bundler-cache: true
      - run: gem install gem_guard
      - run: gem_guard scan --format json --output vulnerabilities.json
      - run: gem_guard typosquat --format json --output typosquats.json
      - run: gem_guard sbom --output sbom.json
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: security-reports
          path: |
            vulnerabilities.json
            typosquats.json
            sbom.json
```

**GitLab CI**

```yaml
security_scan:
  stage: test
  image: ruby:3.2
  before_script:
    - bundle install
    - gem install gem_guard
  script:
    - gem_guard scan --format json --output vulnerabilities.json
    - gem_guard typosquat --format json --output typosquats.json
    - gem_guard sbom --output sbom.json
  artifacts:
    reports:
      dependency_scanning: vulnerabilities.json
    paths:
      - "*.json"
    when: always
  allow_failure: false
```

**CircleCI**

```yaml
version: 2.1
jobs:
  security:
    docker:
      - image: cimg/ruby:3.2
    steps:
      - checkout
      - run: bundle install
      - run: gem install gem_guard
      - run: gem_guard scan --fail-on-vulnerabilities
      - run: gem_guard typosquat
      - run: gem_guard sbom --output sbom.json
      - store_artifacts:
          path: sbom.json
```

## Troubleshooting

**`InvalidLockfileError`** — GemGuard couldn't parse `Gemfile.lock`. Regenerate it with `bundle install`. If that doesn't fix it, delete the lockfile and reinstall from scratch, and confirm it hasn't been hand-edited.

**`FileError`** — GemGuard couldn't read or write a required file. Common causes: missing `Gemfile` (pass `--gemfile PATH`), missing `Gemfile.lock` (run `bundle install` or pass `--lockfile PATH`), no write permission for backups or output (`chmod u+w .`, or write to a mounted volume like `/tmp` in CI). Add `--verbose` for diagnostics.

## Development

```bash
bundle install
bundle exec rspec          # tests
bundle exec rake standard  # linter
bundle exec rake           # both
```

Releases are automated: bump `lib/gem_guard/version.rb`, push to `main`, and GitHub Actions tags, tests across Ruby versions, and publishes to RubyGems.

### Contributing

1. Fork and branch off `main`
2. Write tests first — this codebase uses outside-in TDD
3. `bundle exec rspec` and `bundle exec rake standard` before opening a PR
4. Keep commits descriptive; keep abstractions minimal and intention-revealing

## Roadmap

- [x] Multi-source vulnerability scanning
- [ ] Automated dependency-update suggestions beyond `fix`
- [ ] Web dashboard
- [ ] IDE integrations (VS Code, RubyMine)
- [ ] Slack/Teams alerting
- [ ] Custom rules engine

## License

MIT. See [LICENSE.txt](LICENSE.txt).

## Security

Found a vulnerability in GemGuard itself? See [SECURITY.md](SECURITY.md) for disclosure.

## Acknowledgments

Vulnerability data from [OSV.dev](https://osv.dev/), the [Ruby Advisory Database](https://github.com/rubysec/ruby-advisory-db), [GitHub Security Advisories](https://github.com/advisories), [NVD](https://nvd.nist.gov/), and the [Curesec Advisory Database](https://github.com/curesec/curesec-advisory-db).
