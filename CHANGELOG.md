# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2025-08-17

### Added
- Interactive fix flow: `gem_guard fix --interactive` prompts per gem (via `tty-prompt`).

### Changed
- Dry-run output refined to: `✅ Would update <gem> <from> → <to>` for clarity.

### Dependencies
- Add runtime dependency: `tty-prompt ~> 0.23`.

## [1.1.2] - 2025-08-11

### Added
- Auto-Fix Mode: `gem_guard fix` to automatically update vulnerable gems with safe versions
- SBOM generation: SPDX and CycloneDX outputs via `gem_guard sbom`
- Typosquat detection with fuzzy matching and RubyGems API integration

### Changed
- Standardized CLI exit codes (0: clean, 1: vulnerabilities, 2: error)
- Improved integration test mocking; tests run fast without external calls
- Dropped Ruby 3.0 from CI matrix; now testing 3.1, 3.2, 3.3
- SECURITY.md updated to use GitHub Security Advisories for private reports (no direct email)

### Fixed
- Deduplicated platform-specific gem vulnerabilities in reports
- Resolved config state leakage across tests via deep copy of defaults
- CI/CD publishing issues (RubyGems token permissions, bundler as dev dependency)
- CLI integration test exit code handling and minor lint issues

## [0.1.0] - 2025-08-08

### Added
- Initial release of GemGuard
- Core vulnerability scanning functionality
- Support for OSV.dev vulnerability database
- CLI interface with `scan` and `version` commands
- Table and JSON output formats
- Comprehensive test suite with RSpec
- Integration with Bundler for Gemfile.lock parsing
- Fix recommendations for vulnerable dependencies

### Features
- Parse Gemfile.lock and build dependency graph
- Fetch vulnerabilities from OSV.dev API
- Match dependencies against known vulnerabilities
- Generate human-readable and JSON reports
- Exit with non-zero status when vulnerabilities found
- Support for custom lockfile paths
